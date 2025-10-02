-- Digital IDs Table for Blockchain Integration
-- Run this SQL command in your Supabase SQL Editor

CREATE TABLE IF NOT EXISTS digital_ids (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    digital_id_hash TEXT UNIQUE NOT NULL,
    transaction_id TEXT NOT NULL,
    block_number INTEGER NOT NULL,
    smart_contract TEXT NOT NULL,
    network TEXT NOT NULL DEFAULT 'Tourist-Safety-Chain',
    kyc_reference TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    verification_level TEXT DEFAULT 'basic',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_digital_ids_user_id ON digital_ids(user_id);
CREATE INDEX IF NOT EXISTS idx_digital_ids_hash ON digital_ids(digital_id_hash);
CREATE INDEX IF NOT EXISTS idx_digital_ids_status ON digital_ids(status);
CREATE INDEX IF NOT EXISTS idx_digital_ids_txn_id ON digital_ids(transaction_id);

-- Enable Row Level Security (RLS)
ALTER TABLE digital_ids ENABLE ROW LEVEL SECURITY;

-- Create policies for security
CREATE POLICY "Users can view their own digital IDs" ON digital_ids
    FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert their own digital IDs" ON digital_ids
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update their own digital IDs" ON digital_ids
    FOR UPDATE USING (auth.uid()::text = user_id);

-- Create function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_digital_ids_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-updating updated_at
CREATE TRIGGER update_digital_ids_updated_at_trigger
    BEFORE UPDATE ON digital_ids
    FOR EACH ROW
    EXECUTE FUNCTION update_digital_ids_updated_at();

-- Insert sample digital ID for testing (optional)
-- INSERT INTO digital_ids (
--     user_id, 
--     digital_id_hash, 
--     transaction_id, 
--     block_number, 
--     smart_contract,
--     network,
--     status,
--     verification_level
-- ) VALUES (
--     'sample-user-123',
--     'a1b2c3d4e5f6789012345678901234567890abcdef',
--     'txn_abc123def456',
--     1001,
--     '0x1234567890abcdef1234567890abcdef12345678',
--     'Tourist-Safety-Chain',
--     'verified',
--     'enhanced'
-- );