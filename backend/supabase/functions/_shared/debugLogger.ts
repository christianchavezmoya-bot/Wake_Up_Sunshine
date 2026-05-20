// @ts-nocheck — Deno runtime globals not available in local TS config
/**
 * Shared debug logger for Supabase Edge Functions
 * Logs to both console and debug_events table
 */

export interface DebugEvent {
  trace_id: string
  user_id?: string
  platform?: 'ios' | 'android' | 'backend'
  event_type: string
  message: string
  metadata?: Record<string, any>
}

/**
 * Log a debug event to the debug_events table
 */
export async function logDebugEvent(
  supabaseAdmin: any,
  event: DebugEvent
): Promise<void> {
  try {
    await supabaseAdmin
      .from('debug_events')
      .insert({
        trace_id: event.trace_id,
        user_id: event.user_id || null,
        platform: event.platform || 'backend',
        event_type: event.event_type,
        message: event.message,
        metadata: event.metadata || {}
      })
  } catch (error) {
    // Don't fail the main request if debug logging fails
    console.error('[debugLogger] Failed to log debug event:', error)
  }
}

/**
 * Generate a trace ID for request tracking
 */
export function generateTraceId(): string {
  return `${Date.now()}-${crypto.randomUUID().replace(/-/g, '').slice(0, 16)}`
}

/**
 * Log function start with trace ID
 */
export async function logFunctionStart(
  supabaseAdmin: any,
  traceId: string,
  functionName: string,
  userId?: string,
  requestBody?: any
): Promise<void> {
  console.log(`[${functionName}] START | traceId: ${traceId} | userId: ${userId || 'anonymous'}`)
  
  await logDebugEvent(supabaseAdmin, {
    trace_id: traceId,
    user_id: userId,
    event_type: `${functionName}_start`,
    message: `Function started`,
    metadata: {
      requestBody: sanitizeRequestBody(requestBody)
    }
  })
}

/**
 * Log function end with trace ID
 */
export async function logFunctionEnd(
  supabaseAdmin: any,
  traceId: string,
  functionName: string,
  success: boolean,
  result?: any,
  error?: string
): Promise<void> {
  const status = success ? 'SUCCESS' : 'ERROR'
  console.log(`[${functionName}] END | traceId: ${traceId} | status: ${status}${error ? ` | error: ${error}` : ''}`)
  
  await logDebugEvent(supabaseAdmin, {
    trace_id: traceId,
    event_type: `${functionName}_end`,
    message: `Function completed: ${status}`,
    metadata: {
      success,
      error: error || null,
      resultSummary: summarizeResult(result)
    }
  })
}

/**
 * Log database query result
 */
export async function logDbQuery(
  supabaseAdmin: any,
  traceId: string,
  queryName: string,
  resultCount: number,
  error?: string
): Promise<void> {
  console.log(`[DB] ${queryName} | traceId: ${traceId} | count: ${resultCount}${error ? ` | error: ${error}` : ''}`)
  
  await logDebugEvent(supabaseAdmin, {
    trace_id: traceId,
    event_type: 'db_query',
    message: `Query: ${queryName}`,
    metadata: {
      queryName,
      resultCount,
      error: error || null
    }
  })
}

/**
 * Log push notification attempt
 */
export async function logPushAttempt(
  supabaseAdmin: any,
  traceId: string,
  targetUserId: string,
  platform: 'ios' | 'android',
  success: boolean,
  error?: string
): Promise<void> {
  console.log(`[PUSH] ${platform.toUpperCase()} | traceId: ${traceId} | target: ${targetUserId} | success: ${success}${error ? ` | error: ${error}` : ''}`)
  
  await logDebugEvent(supabaseAdmin, {
    trace_id: traceId,
    user_id: targetUserId,
    platform,
    event_type: 'push_attempt',
    message: `Push notification ${success ? 'sent' : 'failed'}`,
    metadata: {
      targetUserId,
      platform,
      success,
      error: error || null
    }
  })
}

// Helper: Sanitize request body for logging (remove sensitive data)
function sanitizeRequestBody(body: any): any {
  if (!body) return null
  
  const sanitized = { ...body }
  // Remove sensitive fields
  delete sanitized.token
  delete sanitized.password
  delete sanitized.accessToken
  
  return sanitized
}

// Helper: Summarize result for logging (avoid large payloads)
function summarizeResult(result: any): any {
  if (!result) return null
  
  if (Array.isArray(result)) {
    return { count: result.length, type: 'array' }
  }
  
  if (typeof result === 'object') {
    const keys = Object.keys(result)
    if (keys.length > 10) {
      return { keys: keys.slice(0, 10), type: 'object', truncated: true }
    }
    return { keys, type: 'object' }
  }
  
  return { type: typeof result }
}