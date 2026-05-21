ALTER TABLE elderly ADD COLUMN IF NOT EXISTS first_name VARCHAR(100);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS gender VARCHAR(20) CHECK (gender IN ('male', 'female'));
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS blood_type VARCHAR(5);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS emergency_contact_name VARCHAR(255);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS emergency_contact_phone VARCHAR(20);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS emergency_contact_relationship VARCHAR(50);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS emergency_contact_email VARCHAR(255);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS medical_conditions TEXT;
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS allergies TEXT;
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS current_medications TEXT;
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS doctor_name VARCHAR(255);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS doctor_phone VARCHAR(20);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS hospital_preference VARCHAR(255);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS mobility_level VARCHAR(50) CHECK (mobility_level IN ('independent', 'needs_assistance', 'wheelchair', 'bedridden'));
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS address VARCHAR(255);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS city VARCHAR(100);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS state VARCHAR(100);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS typical_sleep_time TIME;
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS typical_wake_time TIME;
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20);
ALTER TABLE elderly ADD COLUMN IF NOT EXISTS country VARCHAR(100) DEFAULT 'Egypt';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'elderly' AND column_name = 'name') THEN
        
        -- Split name into first and last
        UPDATE elderly 
        SET first_name = SPLIT_PART(name, ' ', 1),
            last_name = CASE 
                WHEN ARRAY_LENGTH(STRING_TO_ARRAY(name, ' '), 1) > 1 
                THEN SUBSTRING(name FROM POSITION(' ' IN name) + 1)
                ELSE name
            END
        WHERE first_name IS NULL;
        
    END IF;
END $$;


UPDATE elderly SET first_name = 'Unknown' WHERE first_name IS NULL;
UPDATE elderly SET last_name = 'Unknown' WHERE last_name IS NULL;
UPDATE elderly SET date_of_birth = '1950-01-01' WHERE date_of_birth IS NULL;
UPDATE elderly SET emergency_contact_name = 'Emergency Contact' WHERE emergency_contact_name IS NULL;
UPDATE elderly SET emergency_contact_phone = 'Not provided' WHERE emergency_contact_phone IS NULL;


ALTER TABLE elderly ALTER COLUMN first_name SET NOT NULL;
ALTER TABLE elderly ALTER COLUMN last_name SET NOT NULL;
ALTER TABLE elderly ALTER COLUMN date_of_birth SET NOT NULL;
ALTER TABLE elderly ALTER COLUMN emergency_contact_name SET NOT NULL;
ALTER TABLE elderly ALTER COLUMN emergency_contact_phone SET NOT NULL;


CREATE INDEX IF NOT EXISTS idx_elderly_name ON elderly(first_name, last_name);
CREATE INDEX IF NOT EXISTS idx_elderly_emergency_phone ON elderly(emergency_contact_phone);
CREATE INDEX IF NOT EXISTS idx_elderly_dob ON elderly(date_of_birth);

COMMENT ON COLUMN elderly.first_name IS 'Elderly person first name';
COMMENT ON COLUMN elderly.last_name IS 'Elderly person last name';
COMMENT ON COLUMN elderly.date_of_birth IS 'Date of birth for age calculation';
COMMENT ON COLUMN elderly.medical_conditions IS 'Chronic conditions, diseases (e.g. Diabetes, Hypertension)';
COMMENT ON COLUMN elderly.allergies IS 'Drug allergies, food allergies';
COMMENT ON COLUMN elderly.emergency_contact_name IS 'Primary emergency contact full name';
COMMENT ON COLUMN elderly.emergency_contact_phone IS 'Primary emergency contact phone number';
COMMENT ON COLUMN elderly.typical_sleep_time IS 'Usual bedtime for anomaly detection (e.g. 22:00)';
COMMENT ON COLUMN elderly.typical_wake_time IS 'Usual wake time for anomaly detection (e.g. 07:00)';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✓ Migration complete! Added elderly profile fields.';
END $$;






















