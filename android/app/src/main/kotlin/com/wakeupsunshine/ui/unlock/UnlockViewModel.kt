package com.wakeupsunshine.ui.unlock

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.android.billingclient.api.*
import com.wakeupsunshine.data.UnlockRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for unlock/purchase functionality
 */
class UnlockViewModel(application: Application) : AndroidViewModel(application), PurchasesUpdatedListener {
    
    private val context: Context = application.applicationContext
    
    // State
    private val _isUnlocked = MutableStateFlow(false)
    val isUnlocked: StateFlow<Boolean> = _isUnlocked.asStateFlow()
    
    private val _isInvited = MutableStateFlow(false)
    val isInvited: StateFlow<Boolean> = _isInvited.asStateFlow()
    
    private val _inviteCredits = MutableStateFlow(0)
    val inviteCredits: StateFlow<Int> = _inviteCredits.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()
    
    private val _productPrice = MutableStateFlow("")
    val productPrice: StateFlow<String> = _productPrice.asStateFlow()
    
    private val _currentInvite = MutableStateFlow<UnlockRepository.UnlockInvite?>(null)
    val currentInvite: StateFlow<UnlockRepository.UnlockInvite?> = _currentInvite.asStateFlow()
    
    private val _redeemResult = MutableStateFlow<UnlockRepository.RedeemResult?>(null)
    val redeemResult: StateFlow<UnlockRepository.RedeemResult?> = _redeemResult.asStateFlow()
    
    // Device ID
    val deviceId: String
        get() = UnlockRepository.getDeviceId(context)
    
    // Billing Client
    private var billingClient: BillingClient? = null
    private var productDetails: ProductDetails? = null
    
    init {
        initBillingClient()
        checkUnlockStatus()
    }
    
    // MARK: - Billing
    
    private fun initBillingClient() {
        billingClient = BillingClient.newBuilder(context)
            .setListener(this)
            .enablePendingPurchases()
            .build()
        
        billingClient?.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    loadProduct()
                } else {
                    android.util.Log.e("UnlockViewModel", "Billing setup failed: ${billingResult.debugMessage}")
                }
            }
            
            override fun onBillingServiceDisconnected() {
                // Try to reconnect
                billingClient?.startConnection(this)
            }
        })
    }
    
    private fun loadProduct() {
        val productList = listOf(
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(UnlockRepository.PRODUCT_ID)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        )
        
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productList)
            .build()
        
        billingClient?.queryProductDetailsAsync(params) { billingResult, productDetailsList ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && productDetailsList.isNotEmpty()) {
                productDetails = productDetailsList[0]
                _productPrice.value = productDetailsList[0].oneTimePurchaseOfferDetails?.formattedPrice ?: ""
            }
        }
    }
    
    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: MutableList<Purchase>?) {
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                purchases?.forEach { purchase ->
                    handlePurchase(purchase)
                }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                _error.value = "Purchase cancelled"
            }
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                // Already owned, validate with backend
                viewModelScope.launch {
                    validateExistingPurchase()
                }
            }
            else -> {
                _error.value = "Purchase failed: ${billingResult.debugMessage}"
            }
        }
    }
    
    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
            if (!purchase.isAcknowledged) {
                // Acknowledge the purchase
                val params = AcknowledgePurchaseParams.newBuilder()
                    .setPurchaseToken(purchase.purchaseToken)
                    .build()
                
                billingClient?.acknowledgePurchase(params) { billingResult ->
                    if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                        // Validate with backend
                        validatePurchaseWithBackend(purchase.purchaseToken)
                    }
                }
            } else {
                // Already acknowledged, just validate
                validatePurchaseWithBackend(purchase.purchaseToken)
            }
        }
    }
    
    private fun validatePurchaseWithBackend(purchaseToken: String) {
        viewModelScope.launch {
            _isLoading.value = true
            
            val result = UnlockRepository.validatePurchase(
                deviceId = deviceId,
                purchaseToken = purchaseToken
            )
            
            result.onSuccess { response ->
                if (response.success) {
                    _isUnlocked.value = true
                    _inviteCredits.value = response.inviteCredits ?: 2
                } else {
                    _error.value = response.error ?: "Validation failed"
                }
            }.onFailure { e ->
                _error.value = e.message ?: "Validation failed"
            }
            
            _isLoading.value = false
        }
    }
    
    private suspend fun validateExistingPurchase() {
        val purchasesResult = billingClient?.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        )
        
        purchasesResult?.purchasesList?.forEach { purchase ->
            if (purchase.products.contains(UnlockRepository.PRODUCT_ID)) {
                validatePurchaseWithBackend(purchase.purchaseToken)
            }
        }
    }
    
    // MARK: - Public Methods
    
    fun checkUnlockStatus() {
        viewModelScope.launch {
            _isLoading.value = true
            
            val result = UnlockRepository.getUnlockStatus(deviceId)
            
            result.onSuccess { status ->
                _isUnlocked.value = status.hasPaid
                _isInvited.value = status.isInvited
                _inviteCredits.value = status.inviteCredits
            }.onFailure { e ->
                android.util.Log.e("UnlockViewModel", "Failed to check status", e)
            }
            
            _isLoading.value = false
        }
    }
    
    fun purchase() {
        val details = productDetails ?: return
        
        val productDetailsParamsList = listOf(
            BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(details)
                .build()
        )
        
        val billingFlowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(productDetailsParamsList)
            .build()
        
        billingClient?.launchBillingFlow(context as android.app.Activity, billingFlowParams)
    }
    
    fun createInvite() {
        viewModelScope.launch {
            _isLoading.value = true
            
            val result = UnlockRepository.createInvite(deviceId)
            
            result.onSuccess { invite ->
                if (invite.success) {
                    _currentInvite.value = invite
                    _inviteCredits.value = invite.remainingCredits ?: 0
                } else {
                    _error.value = invite.error ?: "Failed to create invite"
                }
            }.onFailure { e ->
                _error.value = e.message ?: "Failed to create invite"
            }
            
            _isLoading.value = false
        }
    }
    
    fun redeemInvite(code: String) {
        viewModelScope.launch {
            _isLoading.value = true
            
            val result = UnlockRepository.redeemInvite(code, deviceId)
            
            result.onSuccess { redeemResult ->
                _redeemResult.value = redeemResult
                if (redeemResult.success) {
                    _isUnlocked.value = true
                    _isInvited.value = true
                }
            }.onFailure { e ->
                _redeemResult.value = UnlockRepository.RedeemResult(
                    success = false,
                    error = e.message,
                    message = null,
                    status = null,
                    userId = null
                )
            }
            
            _isLoading.value = false
        }
    }
    
    fun clearError() {
        _error.value = null
    }
    
    fun clearRedeemResult() {
        _redeemResult.value = null
    }
}