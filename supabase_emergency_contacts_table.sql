-- Emergency Contacts Table for Raahi App
-- This table stores emergency contacts for each user

CREATE TABLE IF NOT EXISTS emergency_contacts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    relationship VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id ON emergency_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_is_primary ON emergency_contacts(is_primary);

-- Add foreign key constraint to link with user_profiles table
ALTER TABLE emergency_contacts 
ADD CONSTRAINT fk_emergency_contacts_user_id 
FOREIGN KEY (user_id) 
REFERENCES auth.users(id) 
ON DELETE CASCADE;

-- Enable Row Level Security (RLS)
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to only see their own emergency contacts
CREATE POLICY "Users can view their own emergency contacts" ON emergency_contacts
    FOR SELECT USING (auth.uid() = user_id);

-- Create policy to allow users to insert their own emergency contacts
CREATE POLICY "Users can insert their own emergency contacts" ON emergency_contacts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create policy to allow users to update their own emergency contacts
CREATE POLICY "Users can update their own emergency contacts" ON emergency_contacts
    FOR UPDATE USING (auth.uid() = user_id);

-- Create policy to allow users to delete their own emergency contacts
CREATE POLICY "Users can delete their own emergency contacts" ON emergency_contacts
    FOR DELETE USING (auth.uid() = user_id);

-- Function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_emergency_contacts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at on row updates
CREATE TRIGGER trigger_update_emergency_contacts_updated_at
    BEFORE UPDATE ON emergency_contacts
    FOR EACH ROW
    EXECUTE FUNCTION update_emergency_contacts_updated_at();

-- Insert some sample data (optional - remove in production)
-- This shows the structure and can be removed after testing
/*
INSERT INTO emergency_contacts (user_id, name, phone_number, relationship, email, is_primary) VALUES
(
    'sample-user-id-here', 
    'John Smith', 
    '+91-98765-43210', 
    'Father', 
    'john.smith@email.com', 
    true
);
*/