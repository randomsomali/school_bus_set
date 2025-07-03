#include <Adafruit_Fingerprint.h>
#include <LiquidCrystal_I2C.h>
#include <HardwareSerial.h>
#include <TinyGPS++.h>
#include <SoftwareSerial.h>
#include <EEPROM.h>
#include <esp_system.h>
#include <DHT.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "Setsom";
const char* password = "0614444243";

// Backend configuration
const char* serverURL = "http://192.168.100.92:6100/api/esp32/fingerprint/poll";
const char* attendanceURL = "http://192.168.100.92:6100/api/esp32/fingerprint/attendance";
const char* deviceURL = "http://192.168.100.92:6100/api/device";
const unsigned long pollInterval = 3000; // Poll every 3 seconds
const unsigned long sensorInterval = 5000; // Send sensor data every 5 seconds
unsigned long lastPollTime = 0;
unsigned long lastSensorTime = 0;

// Fingerprint Sensor on UART2 (GPIO 16 RX, GPIO 17 TX)
HardwareSerial mySerial(2);
Adafruit_Fingerprint finger = Adafruit_Fingerprint(&mySerial);

// LCD
LiquidCrystal_I2C lcd(0x27, 16, 2);

// GPIO
#define RED_LED 12
#define GREEN_LED 13
#define BUZZER 14

// DHT11 Sensor
#define DHTPIN 19
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

// Gas Sensor (Digital)
#define GAS_SENSOR_PIN 18

// GPS
static const int RXPin = 27, TXPin = 26;
static const uint32_t GPSBaud = 9600;
TinyGPSPlus gps;
SoftwareSerial ss(RXPin, TXPin);

#define MAX_USERS 127
#define NAME_LENGTH 20

uint8_t enrollID = 1;
int mode = 2; // Default to scan mode
unsigned long lastFingerprintCheck = 0;
const unsigned long fingerprintInterval = 1000;

unsigned long lastSensorRead = 0;
const unsigned long sensorReadInterval = 5000;

// Command handling
bool waitingForCommand = false;
int pendingCommandCode = 0;
int pendingFingerprintId = 0;
String pendingStudentName = "";

// Sensor data variables
float currentTemperature = 0.0;
float currentHumidity = 0.0;
int currentGasStatus = 0;
double currentLatitude = 0.0;
double currentLongitude = 0.0;

void lcdPrintMultiLine(const String &line1, const String &line2 = "") {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1);
  if (line2.length() > 0) {
    lcd.setCursor(0, 1);
    lcd.print(line2);
  }
}


void setup() {
  Serial.begin(115200);
  ss.begin(GPSBaud);
  mySerial.begin(57600, SERIAL_8N1, 16, 17);
  EEPROM.begin(MAX_USERS * NAME_LENGTH);
  finger.begin(57600);
  lcd.init();
  lcd.backlight();

  pinMode(RED_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(GAS_SENSOR_PIN, INPUT);

  dht.begin();

  // Initialize WiFi
  initWiFi();

  if (finger.verifyPassword()) {
    Serial.println("Fingerprint sensor ready");
    lcdPrintMultiLine("Fingerprint", "Sensor Ready");
  } else {
    Serial.println("Fingerprint Fail");
    lcdPrintMultiLine("Fingerprint", "Sensor Fail");
    while (1);
  }

  Serial.println("System Ready - Polling Backend");
  lcdPrintMultiLine("System Ready", "Polling Backend");
  delay(2000);
}

void loop() {
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    lcd.setCursor(0, 1);
    lcd.print("WiFi: Reconnecting");
    initWiFi();
  }

  // Poll backend for commands
  if (millis() - lastPollTime >= pollInterval) {
    checkBackendCommand();
    lastPollTime = millis();
  }

  // Send sensor data to device endpoint
  if (millis() - lastSensorTime >= sensorInterval) {
    readAndSendSensorData();
    lastSensorTime = millis();
  }

  // Handle pending commands
  if (waitingForCommand) {
    handlePendingCommand();
  }

  // Fingerprint handling (only in scan mode)
  if (mode == 2 && millis() - lastFingerprintCheck >= fingerprintInterval) {
    lastFingerprintCheck = millis();
    handleFingerprint();
  }

  // Read sensors for local monitoring
  if (millis() - lastSensorRead >= sensorReadInterval) {
    lastSensorRead = millis();
    readSensors();
  }

  // Gas detection with immediate alert
  if (digitalRead(GAS_SENSOR_PIN) == LOW) {
    Serial.println("⚠ GAS DETECTED!");
    for (int i = 0; i < 5; i++) {
      digitalWrite(BUZZER, HIGH);
      delay(200);
      digitalWrite(BUZZER, LOW);
      delay(200);
    }
  }
}

void initWiFi() {
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  
  lcdPrintMultiLine("Connecting", "WiFi...");
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("");
    Serial.print("WiFi connected! IP: ");
    Serial.println(WiFi.localIP());
    
  lcdPrintMultiLine("WiFi Connected", WiFi.localIP().toString());
    delay(2000);
    
    lcdPrintMultiLine("System Ready", "Polling Backend");
  } else {
    Serial.println("WiFi connection failed!");
    lcdPrintMultiLine("WiFi Failed!", "Check credentials");
  }
}

void readSensors() {
  // Read temperature and humidity
  currentTemperature = dht.readTemperature();
  currentHumidity = dht.readHumidity();
  
  // Read gas sensor
  currentGasStatus = digitalRead(GAS_SENSOR_PIN) == LOW ? 1 : 0;
  
  // Read GPS data
  while (ss.available() > 0) {
    if (gps.encode(ss.read())) {
      if (gps.location.isValid()) {
        currentLatitude = gps.location.lat();
        currentLongitude = gps.location.lng();
      }
    }
  }

  Serial.print("Temperature: ");
  Serial.print(currentTemperature);
  Serial.print("°C, Humidity: ");
  Serial.print(currentHumidity);
  Serial.print("%, Gas: ");
  Serial.print(currentGasStatus);
  Serial.print(", GPS: ");
  Serial.print(currentLatitude, 6);
  Serial.print(", ");
  Serial.println(currentLongitude, 6);
}

void readAndSendSensorData() {
  // Read current sensor values
  readSensors();
  
  // Send to device endpoint
  sendSensorDataToBackend();
}

void sendSensorDataToBackend() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, cannot send sensor data");
    return;
  }

  HTTPClient http;
  http.setTimeout(10000);
  
  if (!http.begin(deviceURL)) {
    Serial.println("Failed to begin HTTP connection for sensor data");
    http.end();
    return;
  }
  
  http.addHeader("Content-Type", "application/json");
  
  // Create JSON payload for device data
  DynamicJsonDocument doc(512);
  doc["temperature"] = currentTemperature;
  doc["humidity"] = currentHumidity;
  doc["gasSensor"] = currentGasStatus;
  doc["latitude"] = currentLatitude;
  doc["longitude"] = currentLongitude;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.println("Sending sensor data: " + jsonString);
  
  int httpResponseCode = http.PUT(jsonString);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("Sensor data response: " + response);
    
    DynamicJsonDocument responseDoc(512);
    DeserializationError error = deserializeJson(responseDoc, response);
    
    if (!error) {
      bool success = responseDoc["success"];
      if (success) {
        Serial.println("Sensor data sent successfully");
      } else {
        String message = responseDoc["message"];
        Serial.println("Sensor data failed: " + message);
      }
    }
  } else {
    Serial.println("Sensor data HTTP request failed with code: " + String(httpResponseCode));
  }
  
  http.end();
}

void checkBackendCommand() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, skipping poll");
    return;
  }

  HTTPClient http;
  http.setTimeout(10000);
  
  if (!http.begin(serverURL)) {
    Serial.println("Failed to begin HTTP connection");
    http.end();
    return;
  }
  
  http.addHeader("Content-Type", "application/json");
  http.addHeader("User-Agent", "ESP32-Fingerprint/1.0");
  
  int httpResponseCode = http.GET();
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      bool success = doc["success"];
      
      if (success) {
        int code = doc["code"];
        String message = doc["message"];
        
        Serial.println("Command received from backend:");
        Serial.println("   Code: " + String(code));
        Serial.println("   Message: " + message);
        
        // Process the command
        if (code == 1) { // Enroll new fingerprint
          pendingCommandCode = code;
          pendingFingerprintId = doc["fingerprintId"];
          pendingStudentName = doc["studentName"].as<String>();
          waitingForCommand = true;
          
          Serial.println("   Fingerprint ID: " + String(pendingFingerprintId));
          Serial.println("   Student Name: " + pendingStudentName);
          
          lcdPrintMultiLine("New Student", "Enrolling...");
        } else if (code == 2) { // Delete fingerprint
          pendingCommandCode = code;
          pendingFingerprintId = doc["fingerprintId"];
          pendingStudentName = doc["studentName"].as<String>();
          waitingForCommand = true;
          
          Serial.println("   Fingerprint ID: " + String(pendingFingerprintId));
          Serial.println("   Student Name: " + pendingStudentName);
          
          lcdPrintMultiLine("Delete Student", "Removing...");
        }
      } else {
        // No pending commands - this is normal
        Serial.println("No pending commands");
      }
    } else {
      Serial.println("JSON parsing failed: " + String(error.c_str()));
    }
  } else {
    Serial.println("HTTP request failed with code: " + String(httpResponseCode));
  }
  
  http.end();
}

void handlePendingCommand() {
  if (pendingCommandCode == 1) {
    // Enroll new fingerprint
    enrollFingerprintFromBackend();
  } else if (pendingCommandCode == 2) {
    // Delete fingerprint
    deleteFingerprintFromBackend();
  }
  
  // Clear pending command
  waitingForCommand = false;
  pendingCommandCode = 0;
  pendingFingerprintId = 0;
  pendingStudentName = "";
  
  // Return to scan mode
  mode = 2;
  lcdPrintMultiLine("System Ready", "Scanning...");
}

void enrollFingerprintFromBackend() {
  enrollID = pendingFingerprintId;
  
  Serial.println("Starting enrollment for ID: " + String(enrollID));
  lcdPrintMultiLine("Enrolling ID:", String(enrollID));
  
  // Check if ID is already used
  if (finger.loadModel(enrollID) == FINGERPRINT_OK) {
    Serial.println("ID already used, deleting old fingerprint");
    finger.deleteModel(enrollID);
    delay(1000);
  }
  
  // Store student name in EEPROM
  writeNameToEEPROM(enrollID, pendingStudentName);
  
  Serial.println("Place finger...");
  lcdPrintMultiLine("Place Finger", "...");
  
  int p = -1;
  while (p != FINGERPRINT_OK) {
    p = finger.getImage();
    delay(100);
  }
  
  finger.image2Tz(1);
  Serial.println("Remove finger");
  lcdPrintMultiLine("Remove Finger", "...");
  delay(2000);
  
  while (finger.getImage() != FINGERPRINT_NOFINGER);
  
  Serial.println("Place same finger");
  lcdPrintMultiLine("Place Same", "Finger Again");
  
  while (finger.getImage() != FINGERPRINT_OK);
  finger.image2Tz(2);
  
  p = finger.createModel();
  if (p == FINGERPRINT_OK) {
    finger.storeModel(enrollID);
    Serial.println("Fingerprint stored!");
    lcdPrintMultiLine("Enrollment", "Success!");
    digitalWrite(GREEN_LED, HIGH);
    digitalWrite(BUZZER, HIGH);
    delay(200);
    digitalWrite(BUZZER, LOW);
    digitalWrite(GREEN_LED, LOW);
  } else {
    Serial.println("Enrollment failed");
    lcdPrintMultiLine("Enrollment", "Failed!");
    digitalWrite(RED_LED, HIGH);
    for (int i = 0; i < 3; i++) {
      digitalWrite(BUZZER, HIGH);
      delay(150);
      digitalWrite(BUZZER, LOW);
      delay(150);
    }
    digitalWrite(RED_LED, LOW);
  }
  
  delay(2000);
}

void deleteFingerprintFromBackend() {
  int id = pendingFingerprintId;
  
  Serial.println("Deleting fingerprint ID: " + String(id));
  lcdPrintMultiLine("Deleting ID:", String(id));
  
  if (finger.deleteModel(id) == FINGERPRINT_OK) {
    writeNameToEEPROM(id, "");
    Serial.println("Deleted successfully");
    lcdPrintMultiLine("Delete", "Success!");
    digitalWrite(GREEN_LED, HIGH);
    digitalWrite(BUZZER, HIGH);
    delay(200);
    digitalWrite(BUZZER, LOW);
    digitalWrite(GREEN_LED, LOW);
  } else {
    Serial.println("Delete failed");
    lcdPrintMultiLine("Delete", "Failed!");
    digitalWrite(RED_LED, HIGH);
    for (int i = 0; i < 3; i++) {
      digitalWrite(BUZZER, HIGH);
      delay(150);
      digitalWrite(BUZZER, LOW);
      delay(150);
    }
    digitalWrite(RED_LED, LOW);
  }
  
  delay(2000);
}

void handleFingerprint() {
  lcdPrintMultiLine("Scan Finger...", "");
  int id = getFingerprintID();

  if (id == -1) {
    lcdPrintMultiLine("Scan Finger", "Again");
  } else if (id == 0) {
    lcdPrintMultiLine("Access Denied", "");
    digitalWrite(RED_LED, HIGH);
    for (int i = 0; i < 3; i++) {
      digitalWrite(BUZZER, HIGH);
      delay(150);
      digitalWrite(BUZZER, LOW);
      delay(150);
    }
    digitalWrite(RED_LED, LOW);
  } else {
    showUserInfo(id);
    digitalWrite(GREEN_LED, HIGH);
    digitalWrite(BUZZER, HIGH);
    delay(200);
    digitalWrite(BUZZER, LOW);
    digitalWrite(GREEN_LED, LOW);
    
    // Send attendance to backend
    sendAttendanceToBackend(id);
  }

  delay(1000);
  lcd.clear();
}

int getFingerprintID() {
  uint8_t p = finger.getImage();
  if (p != FINGERPRINT_OK) return -1;
  p = finger.image2Tz();
  if (p != FINGERPRINT_OK) return 0;
  p = finger.fingerSearch();
  if (p != FINGERPRINT_OK) return 0;
  return finger.fingerID;
}

void showUserInfo(int id) {
  lcd.clear();
  lcd.setCursor(0, 0);
  String name = readNameFromEEPROM(id);
  lcd.print(name.length() > 0 ? name.substring(0, 16) : String("User ID:") + id);
  lcd.setCursor(0, 1);
  lcd.print("Present ID: ");
  lcd.print(id);
  Serial.print("ID: "); Serial.print(id);
  Serial.print(" - Name: "); Serial.println(name);
}

void sendAttendanceToBackend(int fingerprintId) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, cannot send attendance");
    return;
  }

  HTTPClient http;
  http.setTimeout(10000);
  
  if (!http.begin(attendanceURL)) {
    Serial.println("Failed to begin HTTP connection for attendance");
    http.end();
    return;
  }
  
  http.addHeader("Content-Type", "application/json");
  
  // Create JSON payload
  DynamicJsonDocument doc(256);
  doc["fingerprintId"] = fingerprintId;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  Serial.println("Sending attendance: " + jsonString);
  
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("Attendance response: " + response);
    
    DynamicJsonDocument responseDoc(512);
    DeserializationError error = deserializeJson(responseDoc, response);
    
    if (!error) {
      bool success = responseDoc["success"];
      if (success) {
        Serial.println("Attendance recorded successfully");
      } else {
        String message = responseDoc["message"];
        Serial.println("Attendance failed: " + message);
      }
    }
  } else {
    Serial.println("Attendance HTTP request failed with code: " + String(httpResponseCode));
  }
  
  http.end();
}

void writeNameToEEPROM(int id, const String &name) {
  int addr = (id - 1) * NAME_LENGTH;
  for (int i = 0; i < NAME_LENGTH; i++) {
    EEPROM.write(addr + i, i < name.length() ? name[i] : '\0');
  }
  EEPROM.commit();
}

String readNameFromEEPROM(int id) {
  int addr = (id - 1) * NAME_LENGTH;
  String name = "";
  for (int i = 0; i < NAME_LENGTH; i++) {
    char c = EEPROM.read(addr + i);
    if (c == '\0') break;
    name += c;
  }
  return name;
}