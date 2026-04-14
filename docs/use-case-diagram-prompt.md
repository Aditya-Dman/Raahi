# Prompt for AI (Use Case Diagram for “Raahi”)

You are a **UML analyst**. Create a **complete UML Use Case Diagram** for a mobile app named **“Raahi – Smart Tourist Safety System”** (Flutter app). The diagram must be consistent with the app features and screens described below.

## 1) System boundary
- System name (inside the box): **Raahi Mobile App**
- Also show major **external systems** (as actors) that the app integrates with:
  - **Supabase (Auth + Database/PostgreSQL + Realtime)**
  - **Google Maps API**
  - **Google Places API**
  - **SMS/Phone Services (Android OS / Telecom)**
  - **GPS/Location Services (Device OS)**
  - **Chatbase AI Webview / AI Agent**
  - (Optional) **Local Storage (SQLite / Shared Preferences)**

## 2) Primary actors (must include)
Create actors and connect them to relevant use cases:

- **Tourist / User (Primary)**
- **Emergency Contact (Secondary)**
- **Emergency Services / Authority / Support (Optional)**
- **External Systems** (the integrations listed above)

## 3) App functional areas (use cases)
Create use cases grouped into these modules. Each bullet should be a use case node in the diagram.

### Authentication & Account
- **Sign Up**
- **Login**
- **Logout**
- **Persist Login Session**
- **View Profile / User Identity Info**

(Associate these with **Supabase** actor.)

### Language / Localization
- **Select Language (English/Hindi)**
- **Load Saved Language Preference**

### Digital Identity + KYC
- **Manage Digital ID**
- **Submit / Update KYC**
- **Check KYC Status (pending/verified/rejected/not_submitted)**

(Associate with **Supabase** actor.)

### Dashboard / Overview
- **View Dashboard Overview**
- **View Safety Score**
- **View Trip / Days Remaining / Summary Stats**
- **View Health Summary**

### GPS Tracking & Maps
- **Grant Location Permission**
- **Start GPS Tracking**
- **Stop GPS Tracking**
- **View Live Map**
- **View Route History**
- **Get Current Location**

(Associate with **GPS/Location Services** + **Google Maps API**.)

### Nearby Places / Tourist Services
- **Search Nearby Places by Category** (restaurants/hotels/medical/transport)
- **View Place Details** (ratings, photos, opening hours, price level)
- **Navigate to Selected Place**

(Associate with **Google Places API**, **Google Maps API**.)

### Geofencing / Safety Zones
- **Configure Safety Zones**
- **Enable/Disable Geofencing**
- **Receive Location-based Safety Alerts**

(Associate with **GPS/Location Services**.)

### Emergency / SOS
- **Grant Phone Permission**
- **Grant SMS Permission**
- **Manage Emergency Contacts** (add/edit/delete/list)
- **Trigger SOS Emergency (3-second hold)**
- **Send SOS SMS to Emergency Contacts**
- **Make Emergency Call** (optional)
- **Play Alarm / Emergency Sound**

(Associate with **SMS/Phone Services** and **Emergency Contact** actor.)

### AI-Powered Features
- **Chat with AI Assistant (Raahi chatbot)**
- **Behavior Tracking**
- **Anomaly Detection**
- **Predictive Safety Alerts / AI Alerts**
- **Generate Recommendations**

(Associate with **Chatbase AI** actor; optionally Supabase if logs/data stored.)

### IoT (minimal)
- **View IoT Devices / IoT Integration**

## 4) Relationships (include / extend)
Use correct UML relationships.

### <<include>> (mandatory examples)
- “Login” <<include>> “Authenticate with Supabase”
- “Sign Up” <<include>> “Create Account in Supabase”
- “Trigger SOS Emergency” <<include>> “Send SOS SMS to Emergency Contacts”
- “Start GPS Tracking” <<include>> “Get Current Location”
- “Search Nearby Places” <<include>> “Fetch Places from Google Places API”
- “View Live Map” <<include>> “Render Map via Google Maps API”
- “Manage Emergency Contacts” <<include>> “Store/Retrieve Contacts (Supabase DB)”
- “Select Language” <<include>> “Save Language Preference”

### <<extend>> (conditional examples)
- “Receive Location-based Safety Alerts” <<extend>> “Geofencing Enabled”
- “Predictive Safety Alerts / AI Alerts” <<extend>> “Anomaly Detected”
- “Make Emergency Call” <<extend>> “Trigger SOS Emergency”
- “View Place Details” <<extend>> “Search Nearby Places”

## 5) Permissions as use cases
Model permissions explicitly as use cases:
- Grant Location Permission
- Grant SMS Permission
- Grant Phone Permission

## 6) Output format requirements
Produce TWO outputs:

1) **A UML use case diagram in PlantUML**
- Provide valid `@startuml ... @enduml`
- Use actors, system boundary, use cases, and include/extend arrows
- Keep it readable: group use cases by sections (Authentication, Emergency, Maps, AI, etc.)

2) **A short explanation**
- List actors
- List major use case groups
- Briefly explain 5–8 key include/extend relationships

## 7) Accuracy constraint
Only use features described here:
- Screens: splash, login/signup, dashboard, digital ID, KYC update, emergency contacts, nearby places, geofencing settings
- Services: Supabase auth/data, emergency alert service, maps/places services, AI chat via Chatbase webview, behavior/anomaly tracking, safety score, health monitoring
Do not invent unrelated features.