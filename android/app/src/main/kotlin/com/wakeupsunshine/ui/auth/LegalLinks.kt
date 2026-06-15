package com.wakeupsunshine.ui.auth

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.text.ClickableText
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.sp
import com.wakeupsunshine.BuildConfig

private const val TAG_TERMS = "terms"
private const val TAG_PRIVACY = "privacy"

@Composable
fun LegalDisclaimer(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val accent = MaterialTheme.colorScheme.primary
    val text = buildLegalDisclaimer(accent)

    ClickableText(
        text = text,
        modifier = modifier,
        style = MaterialTheme.typography.bodySmall.copy(
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 12.sp,
            textAlign = TextAlign.Center
        )
    ) { offset ->
        val annotation = text.getStringAnnotations(start = offset, end = offset).firstOrNull() ?: return@ClickableText
        val url = when (annotation.tag) {
            TAG_TERMS -> BuildConfig.TERMS_OF_SERVICE_URL
            TAG_PRIVACY -> BuildConfig.PRIVACY_POLICY_URL
            else -> return@ClickableText
        }

        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }
}

private fun buildLegalDisclaimer(accent: androidx.compose.ui.graphics.Color): AnnotatedString {
    return buildAnnotatedString {
        append("By continuing, you agree to our ")
        pushStringAnnotation(tag = TAG_TERMS, annotation = BuildConfig.TERMS_OF_SERVICE_URL)
        withStyle(SpanStyle(color = accent, fontWeight = FontWeight.Medium)) {
            append("Terms of Service")
        }
        pop()
        append(" and ")
        pushStringAnnotation(tag = TAG_PRIVACY, annotation = BuildConfig.PRIVACY_POLICY_URL)
        withStyle(SpanStyle(color = accent, fontWeight = FontWeight.Medium)) {
            append("Privacy Policy")
        }
        pop()
    }
}
