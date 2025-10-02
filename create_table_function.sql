-- Auto-Table Creation Function for Supabase
-- Just copy and paste this into your Supabase SQL Editor (one time only)

CREATE OR REPLACE FUNCTION create_emergency_contacts_table()
RETURNS TEXT AS $$
BEGIN
    -- Create the emergency_contacts table if it doesn't exist
    CREATE TABLE IF NOT EXISTS emergency_contacts (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        user_id UUID NOT NULL,
        name TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        relationship TEXT NOT NULL,
        email TEXT,
        is_primary BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Create indexes
    CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id ON emergency_contacts(user_id);
    
    -- Enable Row Level Security
    ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;

    -- Create policies (only if they don't exist)
    DO $$ 
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'emergency_contacts' AND policyname = 'Users can manage their own contacts') THEN
            CREATE POLICY "Users can manage their own contacts" ON emergency_contacts
                FOR ALL USING (auth.uid()::text = user_id::text);
        END IF;
    END $$;

    RETURN 'Emergency contacts table created successfully!';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;