CREATE DATABASE IF NOT EXISTS nexuscrm CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nexuscrm;

CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(100)  NOT NULL,
  email         VARCHAR(255)  UNIQUE NOT NULL,
  password_hash VARCHAR(255)  NOT NULL,
  last_login    DATETIME,
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS contacts (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  user_id    INT NOT NULL,
  name       VARCHAR(100) NOT NULL,
  email      VARCHAR(255) NOT NULL,
  company    VARCHAR(150),
  phone      VARCHAR(50),
  status     ENUM('lead','prospect','customer','churned') DEFAULT 'lead',
  notes      TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS deals (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT NOT NULL,
  contact_id  INT NOT NULL,
  title       VARCHAR(200)  NOT NULL,
  value       DECIMAL(12,2) DEFAULT 0,
  stage       ENUM('lead','qualified','proposal','negotiation','closed_won','closed_lost') DEFAULT 'lead',
  probability INT DEFAULT 10,
  close_date  DATE,
  notes       TEXT,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS activities (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT NOT NULL,
  deal_id     INT,
  contact_id  INT,
  type        VARCHAR(50) NOT NULL,
  description TEXT,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  FOREIGN KEY (deal_id)    REFERENCES deals(id)    ON DELETE SET NULL,
  FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL
);

-- Demo account  password: Demo1234!
INSERT IGNORE INTO users (name,email,password_hash) VALUES
  ('Alex Rivera','demo@nexuscrm.io','$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6qthsHqrUe');

SET @u=(SELECT id FROM users WHERE email='demo@nexuscrm.io');

INSERT IGNORE INTO contacts (user_id,name,email,company,phone,status) VALUES
  (@u,'Sarah Mitchell','sarah@techflow.io',   'TechFlow Inc','+1 555 0101','customer'),
  (@u,'James Okafor',  'james@scaleworks.com','ScaleWorks',  '+1 555 0102','prospect'),
  (@u,'Maria Gonzalez','maria@cloudpeak.co',  'CloudPeak',   '+1 555 0103','lead'),
  (@u,'Liam Chen',     'liam@datasync.ai',    'DataSync AI', '+1 555 0104','prospect'),
  (@u,'Emma Thompson', 'emma@nexagroup.com',  'Nexa Group',  '+1 555 0105','customer');

SET @c1=(SELECT id FROM contacts WHERE email='sarah@techflow.io');
SET @c2=(SELECT id FROM contacts WHERE email='james@scaleworks.com');
SET @c3=(SELECT id FROM contacts WHERE email='maria@cloudpeak.co');
SET @c4=(SELECT id FROM contacts WHERE email='liam@datasync.ai');
SET @c5=(SELECT id FROM contacts WHERE email='emma@nexagroup.com');

INSERT IGNORE INTO deals (user_id,contact_id,title,value,stage,probability,close_date) VALUES
  (@u,@c1,'TechFlow Enterprise License', 85000,'closed_won', 100,'2024-11-15'),
  (@u,@c2,'ScaleWorks Platform Upgrade', 42000,'negotiation', 80,'2025-04-30'),
  (@u,@c3,'CloudPeak Starter Package',   12500,'proposal',    60,'2025-05-10'),
  (@u,@c4,'DataSync AI Integration',     67000,'qualified',   40,'2025-06-01'),
  (@u,@c5,'Nexa Group Annual Renewal',  120000,'closed_won', 100,'2024-12-01'),
  (@u,@c1,'TechFlow Add-on Modules',     28000,'proposal',    55,'2025-05-20'),
  (@u,@c2,'ScaleWorks Support Plan',      9600,'lead',        20,'2025-07-01');

SET @d1=(SELECT id FROM deals WHERE title='TechFlow Enterprise License' AND user_id=@u);
SET @d2=(SELECT id FROM deals WHERE title='ScaleWorks Platform Upgrade'  AND user_id=@u);
SET @d3=(SELECT id FROM deals WHERE title='CloudPeak Starter Package'    AND user_id=@u);

INSERT IGNORE INTO activities (user_id,deal_id,contact_id,type,description) VALUES
  (@u,@d1,@c1,'deal_created',     'Deal "TechFlow Enterprise License" created'),
  (@u,@d1,@c1,'stage_changed',    'Moved negotiation → closed_won'),
  (@u,@d2,@c2,'meeting_scheduled','Demo call scheduled for next Tuesday'),
  (@u,@d3,@c3,'email_sent',       'Sent proposal deck to Maria'),
  (@u,@d2,@c2,'call_logged',      '30-min discovery call — strong interest');
