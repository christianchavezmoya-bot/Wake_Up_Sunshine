-- Debug Events Table for End-to-End Tracing
-- Version: 1.0.0

-- ============================================
-- DEBUG EVENTS TABLE
-- ============================================
CREATE TABLE public.debug_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trace_id TEXT NOT NULL,
    user_id UUID,
    platform TEXT CHECK (platform IN ('ios', 'android', 'backend')),
    event_type TEXT NOT NULL,
    message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for efficient querying
CREATE INDEX idx_debug_events_trace_id ON public.debug_events(trace_id);
CREATE INDEX idx_debug_events_user_id ON public.debug_events(user_id);
CREATE INDEX idx_debug_events_event_type ON public.debug_events(event_type);
CREATE INDEX idx_debug_events_created_at ON public.debug_events(created_at DESC);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE public.debug_events ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own debug events
CREATE POLICY "Users can insert own debug events"
    ON public.debug_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Service role can insert all debug events
CREATE POLICY "Service role can insert all debug events"
    ON public.debug_events FOR INSERT
    WITH CHECK (true);

-- Policy: Users can read their own debug events
CREATE POLICY "Users can read own debug events"
    ON public.debug_events FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Service role can read all debug events
CREATE POLICY "Service role can read all debug events"
    ON public.debug_events FOR SELECT
    USING (true);

-- ============================================
-- HELPER FUNCTION FOR LOGGING
-- ============================================
CREATE OR REPLACE FUNCTION public.log_debug_event(
    p_trace_id TEXT,
    p_event_type TEXT,
    p_message TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}',
    p_platform TEXT DEFAULT 'backend',
    p_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
BEGIN
    INSERT INTO public.debug_events (
        trace_id,
        user_id,
        platform,
        event_type,
        message,
        metadata
    ) VALUES (
        p_trace_id,
        COALESCE(p_user_id, auth.uid()),
        p_platform,
        p_event_type,
        p_message,
        p_metadata
    )
    RETURNING id INTO v_event_id;
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- CLEANUP OLD EVENTS (Optional)
-- ============================================
-- Create a function to clean up events older than 30 days
CREATE OR REPLACE FUNCTION public.cleanup_old_debug_events()
RETURNS void AS $$
BEGIN
    DELETE FROM public.debug_events
    WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- UPDATE USER_DEVICES TABLE
-- ============================================
-- Add is_active column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_devices' 
        AND column_name = 'is_active'
    ) THEN
        ALTER TABLE public.user_devices ADD COLUMN is_active BOOLEAN DEFAULT true;
    END IF;
END $$;

-- Add updated_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_devices' 
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.user_devices ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- Add device_token column if it doesn't exist (rename from token if needed)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_devices' 
        AND column_name = 'device_token'
    ) THEN
        -- Check if 'token' column exists and rename it
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'user_devices' 
            AND column_name = 'token'
        ) THEN
            ALTER TABLE public.user_devices RENAME COLUMN token TO device_token;
        END IF;
    END IF;
END $$;

-- Create index on device_token if not exists
CREATE INDEX IF NOT EXISTS idx_user_devices_device_token ON public.user_devices(device_token);

-- ============================================
-- GRANT PERMISSIONS
-- ============================================
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.debug_events TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_debug_event TO authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_old_debug_events TO authenticated;

COMMENT ON TABLE public.debug_events IS 'Stores debug trace events for end-to-end debugging';
COMMENT ON FUNCTION public.log_debug_event IS 'Helper function to log debug events from Edge Functions or client apps';