#include <ESP32Servo.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "Setsom";
const char* password = "0614444243";

// Backend configuration
const char* serverURL = "http://192.168.100.75:6767/api/esp32/poll";
const unsigned long pollInterval = 2000; // Poll every 2 seconds
unsigned long lastPollTime = 0;

// LCD Setup
LiquidCrystal_I2C lcd(0x27, 20, 4);

// Servos
Servo myServo;
Servo exitServo;
const int servoPin = 4;
const int exitServoPin = 5;
const int closedPosition = 83;
const int openPosition = 3;

// Ultrasonic
const int trigPin = 18;
const int echoPin = 19;
const int trigExitPin = 25;
const int echoExitPin = 26;

// Pumps
const int shampooPumpPin = 2;
const int waterPumpPin = 15;

// LEDs
const int ledShampoo = 32;
const int ledRinse = 13;
const int ledReady = 12;

// Buzzer
const int buzzerPin = 27;

// Timers
unsigned long washStartTime = 0;
const unsigned long shampooTime = 5000;
const unsigned long rinseTime = 5000;

// States
enum State {
  STATE_IDLE,
  STATE_OPENING_DOOR,
  STATE_WAITING_CAR,
  STATE_CLOSING_DOOR,
  STATE_WASHING,
  STATE_OPENING_EXIT,
  STATE_WAITING_EXIT,
  STATE_READY_NEXT
};
State currentState = STATE_IDLE;

enum WashingStage {
  STAGE_NONE,
  STAGE_SHAMPOO,
  STAGE_RINSE
};
WashingStage currentWashingStage = STAGE_NONE;

bool rinseOnlyMode = false;

void setup() {
  Serial.begin(115200);
  delay(1000); // Give serial time to initialize
  
  Serial.println("🚀 Car Wash System Starting...");
  
  // Initialize LCD
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Car Wash System");

  // Initialize WiFi
  initWiFi();

  // Network diagnostics
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("🌐 Network Diagnostics:");
    Serial.println("   ESP32 IP: " + String(WiFi.localIP().toString()));
    Serial.println("   Gateway: " + String(WiFi.gatewayIP().toString()));
    Serial.println("   Subnet: " + String(WiFi.subnetMask().toString()));
    Serial.println("   DNS: " + String(WiFi.dnsIP().toString()));
    Serial.println("   Backend URL: " + String(serverURL));
    
    // Test basic connectivity
    Serial.println("🔍 Testing connectivity to backend server...");
    testBackendConnection();
  }

  // Initialize servos
  myServo.attach(servoPin);
  myServo.write(closedPosition);
  exitServo.attach(exitServoPin);
  exitServo.write(closedPosition);

  // Initialize pins
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  pinMode(trigExitPin, OUTPUT);
  pinMode(echoExitPin, INPUT);

  pinMode(shampooPumpPin, OUTPUT);
  pinMode(waterPumpPin, OUTPUT);
  digitalWrite(shampooPumpPin, HIGH);
  digitalWrite(waterPumpPin, HIGH);

  pinMode(ledShampoo, OUTPUT);
  pinMode(ledRinse, OUTPUT);
  pinMode(ledReady, OUTPUT);
  pinMode(buzzerPin, OUTPUT);

  digitalWrite(ledShampoo, LOW);
  digitalWrite(ledRinse, LOW);
  digitalWrite(ledReady, HIGH);

  clearLinesBelowTitle();
  lcd.setCursor(0, 1);
  lcd.print("System Ready");
  lcd.setCursor(0, 2);
  lcd.print("Waiting for booking");
  
  Serial.println("✅ Car Wash System Initialized");
  Serial.println("🔄 Polling backend for commands...");
}

void loop() {
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    lcd.setCursor(0, 3);
    lcd.print("WiFi: Reconnecting");
    initWiFi();
  }

  // Poll backend for commands if in idle state
  if (currentState == STATE_IDLE && millis() - lastPollTime > pollInterval) {
    checkBackendCommand();
    lastPollTime = millis();
  }

  handleStateMachine();
}

void initWiFi() {
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  
  // Show connecting status on LCD
  clearLinesBelowTitle();
  lcd.setCursor(0, 1);
  lcd.print("Connecting WiFi...");
  
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
    
    clearLinesBelowTitle();
    lcd.setCursor(0, 1);
    lcd.print("WiFi Connected");
    lcd.setCursor(0, 2);
    lcd.print(WiFi.localIP());
    delay(2000);
    
    clearLinesBelowTitle();
    lcd.setCursor(0, 1);
    lcd.print("System Ready");
    lcd.setCursor(0, 2);
    lcd.print("Waiting for booking");
  } else {
    Serial.println("WiFi connection failed!");
    lcd.setCursor(0, 1);
    lcd.print("WiFi Failed!");
    lcd.setCursor(0, 2);
    lcd.print("Check credentials");
  }
}

void checkBackendCommand() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, skipping poll");
    return;
  }

  Serial.println("🔍 Polling backend: " + String(serverURL));
  
  HTTPClient http;
  http.setTimeout(10000); // 10 second timeout
  
  // Try to begin connection
  if (!http.begin(serverURL)) {
    Serial.println("❌ Failed to begin HTTP connection");
    http.end();
    return;
  }
  
  http.addHeader("Content-Type", "application/json");
  http.addHeader("User-Agent", "ESP32-CarWash/1.0");
  
  Serial.println("📡 Sending GET request...");
  int httpResponseCode = http.GET();
  
  Serial.println("📈 HTTP Response Code: " + String(httpResponseCode));
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("📦 Backend Response: " + response);
    
    // Parse JSON response
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      bool success = doc["success"];
      
      if (success) {
        int code = doc["code"];
        String message = doc["message"];
        String serviceName = doc["serviceName"] | "Unknown Service";
        
        Serial.println("✅ Command received from backend:");
        Serial.println("   Code: " + String(code));
        Serial.println("   Message: " + message);
        Serial.println("   Service: " + serviceName);
        
        // Clear backend status on LCD
        lcd.setCursor(0, 3);
        lcd.print("                    ");
        
        // Process the command
        processBackendCommand(code, message, serviceName);
      } else {
        // No pending commands - this is normal
        Serial.println("ℹ️ No pending commands");
        lcd.setCursor(0, 3);
        lcd.print("Backend: Online     ");
      }
    } else {
      Serial.println("❌ JSON parsing failed: " + String(error.c_str()));
      Serial.println("Raw response: " + response);
    }
  } else {
    Serial.println("❌ HTTP request failed with code: " + String(httpResponseCode));
    
    // Detailed error reporting
    switch(httpResponseCode) {
      case HTTPC_ERROR_CONNECTION_REFUSED:
        Serial.println("   → Connection refused (server not accepting connections)");
        break;
      case HTTPC_ERROR_SEND_HEADER_FAILED:
        Serial.println("   → Failed to send headers");
        break;
      case HTTPC_ERROR_SEND_PAYLOAD_FAILED:
        Serial.println("   → Failed to send payload");
        break;
      case HTTPC_ERROR_NOT_CONNECTED:
        Serial.println("   → Not connected to server");
        break;
      case HTTPC_ERROR_CONNECTION_LOST:
        Serial.println("   → Connection lost");
        break;
      case HTTPC_ERROR_NO_STREAM:
        Serial.println("   → No stream available");
        break;
      case HTTPC_ERROR_NO_HTTP_SERVER:
        Serial.println("   → No HTTP server");
        break;
      case HTTPC_ERROR_TOO_LESS_RAM:
        Serial.println("   → Too little RAM");
        break;
      case HTTPC_ERROR_ENCODING:
        Serial.println("   → Encoding error");
        break;
      case HTTPC_ERROR_STREAM_WRITE:
        Serial.println("   → Stream write error");
        break;
      case HTTPC_ERROR_READ_TIMEOUT:
        Serial.println("   → Read timeout");
        break;
      default:
        Serial.println("   → Unknown error");
        break;
    }
    
    // Update LCD to show connection issue
    lcd.setCursor(0, 3);
    lcd.print("Backend: Error " + String(httpResponseCode));
  }
  
  http.end();
}

void processBackendCommand(int code, String message, String serviceName) {
  if (currentState != STATE_IDLE) {
    Serial.println("⚠️ System busy, ignoring command");
    return;
  }

  rinseOnlyMode = (code == 0);

  if (rinseOnlyMode) {
    Serial.println("🚿 Starting Rinse Only Mode");
    clearLinesBelowTitle();
    lcd.setCursor(0, 1);
    lcd.print("Rinse Only Mode");
    lcd.setCursor(0, 2);
    lcd.print(serviceName);
  } else {
    Serial.println("🧽 Starting Full Wash Mode");
    clearLinesBelowTitle();
    lcd.setCursor(0, 1);
    lcd.print("Full Wash Mode");
    lcd.setCursor(0, 2);
    lcd.print(serviceName);
  }

  clearLinesBelowTitle();
  lcd.setCursor(0, 1);
  if (rinseOnlyMode) {
    lcd.print("Rinse Only Mode");
  } else {
    lcd.print("Full Wash Mode");
  }
  lcd.setCursor(0, 2);
  lcd.print("Opening Entry Door");
  
  currentState = STATE_OPENING_DOOR;
}

void handleStateMachine() {
  switch (currentState) {
    case STATE_OPENING_DOOR:
      openDoor();
      Serial.println("Entry Door Opening...");
      clearLinesBelowTitle();
      lcd.setCursor(0, 1);
      lcd.print("Opening Entry Door");
      beep(2);
      currentState = STATE_WAITING_CAR;
      break;

    case STATE_WAITING_CAR: {
      float entryDistance = getEntryDistance();
      if (entryDistance > 0 && entryDistance < 16) {
        Serial.println("Car Detected 🚗");
        clearLinesBelowTitle();
        lcd.setCursor(0, 1);
        lcd.print("Car Detected");
        currentState = STATE_CLOSING_DOOR;
      }
      delay(100);
      break;
    }

    case STATE_CLOSING_DOOR: {
      closeDoor();
      Serial.println("Entry Door Closing...");
      clearLinesBelowTitle();
      lcd.setCursor(0, 1);
      lcd.print("Closing Entry Door");
      beep(2);
      currentState = STATE_WASHING;
      washStartTime = millis();
      currentWashingStage = STAGE_NONE;
      break;
    }

    case STATE_WASHING:
      handleWashing();
      break;

    case STATE_OPENING_EXIT:
      openExitDoor();
      Serial.println("Exit Door Opening...");
      clearLinesBelowTitle();
      lcd.setCursor(0, 1);
      lcd.print("Opening Exit Door");
      beep(2);
      currentState = STATE_WAITING_EXIT;
      break;

    case STATE_WAITING_EXIT: {
      float exitDistance = getExitDistance();
      if (exitDistance > 0 && exitDistance < 17) {
        Serial.println("Car Exiting...");
        clearLinesBelowTitle();
        lcd.setCursor(0, 1);
        lcd.print("Car Exiting...");
        closeExitDoor();
        currentState = STATE_READY_NEXT;
      }
      break;
    }

    case STATE_READY_NEXT:
      digitalWrite(shampooPumpPin, HIGH);
      digitalWrite(waterPumpPin, HIGH);
      digitalWrite(ledShampoo, LOW);
      digitalWrite(ledRinse, LOW);
      rinseOnlyMode = false;
      currentState = STATE_IDLE;
      Serial.println("System Ready for Next Car ✅");
      clearLinesBelowTitle();
      lcd.setCursor(0, 1);
      lcd.print("System Ready");
      lcd.setCursor(0, 2);
      lcd.print("Waiting for booking");
      break;

    case STATE_IDLE:
    default:
      break;
  }
}

void handleWashing() {
  unsigned long elapsed = millis() - washStartTime;

  if (!rinseOnlyMode && elapsed < shampooTime) {
    digitalWrite(shampooPumpPin, LOW);
    digitalWrite(waterPumpPin, HIGH);
    if (currentWashingStage != STAGE_SHAMPOO) {
      Serial.println("Shampooing...");
      clearLinesBelowTitle();
      lcd.setCursor(0, 1);
      lcd.print("Washing: Shampoo");
      digitalWrite(ledShampoo, HIGH);
      digitalWrite(ledRinse, LOW);
      beep(1);
      currentWashingStage = STAGE_SHAMPOO;
    }
  } else if (elapsed < (rinseOnlyMode ? rinseTime : (shampooTime + rinseTime))) {
    digitalWrite(shampooPumpPin, HIGH);
    digitalWrite(waterPumpPin, LOW);
    if (currentWashingStage != STAGE_RINSE) {
      Serial.println("Rinsing...");
      clearLinesBelowTitle();
      lcd.setCursor(0, 1);
      lcd.print("Washing: Rinse");
      digitalWrite(ledShampoo, LOW);
      digitalWrite(ledRinse, HIGH);
      beep(1);
      currentWashingStage = STAGE_RINSE;
    }
  } else {
    digitalWrite(shampooPumpPin, HIGH);
    digitalWrite(waterPumpPin, HIGH);
    digitalWrite(ledShampoo, LOW);
    digitalWrite(ledRinse, LOW);
    Serial.println("Washing Complete ✅");
    clearLinesBelowTitle();
    lcd.setCursor(0, 1);
    lcd.print("Washing Complete");
    beep(3);
    currentState = STATE_OPENING_EXIT;
  }
}

float getEntryDistance() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  long duration = pulseIn(echoPin, HIGH, 20000);
  if (duration == 0) return 999;
  float distance = duration * 0.034 / 2.0;
  return distance;
}

float getExitDistance() {
  digitalWrite(trigExitPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigExitPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigExitPin, LOW);
  long duration = pulseIn(echoExitPin, HIGH, 20000);
  if (duration == 0) return 999;
  float distance = duration * 0.034 / 2.0;
  return distance;
}

void openDoor() {
  for (int pos = closedPosition; pos >= openPosition; pos--) {
    myServo.write(pos);
    delay(10);
  }
}

void closeDoor() {
  for (int pos = openPosition; pos <= closedPosition; pos++) {
    myServo.write(pos);
    delay(10);
  }
}

void openExitDoor() {
  for (int pos = closedPosition; pos >= openPosition; pos--) {
    exitServo.write(pos);
    delay(10);
  }
}

void closeExitDoor() {
  for (int pos = openPosition; pos <= closedPosition; pos++){
    exitServo.write(pos);
    delay(10);
  }
}

void beep(int times) {
  for (int i = 0; i < times; i++) {
    digitalWrite(buzzerPin, HIGH);
    delay(100);
    digitalWrite(buzzerPin, LOW);
    delay(100);
  }
}

void clearLinesBelowTitle() {
  for (int i = 1; i < 4; i++) {
    lcd.setCursor(0, i);
    lcd.print("                    ");
  }
}

void testBackendConnection() {
  Serial.println("🧪 Testing HTTP connection to backend...");
  
  HTTPClient http;
  http.setTimeout(5000);
  
  if (http.begin(serverURL)) {
    Serial.println("✅ HTTP client initialized successfully");
    
    int httpCode = http.GET();
    Serial.println("📡 Test request result: " + String(httpCode));
    
    if (httpCode > 0) {
      String response = http.getString();
      Serial.println("📦 Test response received (" + String(response.length()) + " bytes)");
      Serial.println("🔍 First 200 chars: " + response.substring(0, 200));
    } else {
      Serial.println("❌ Test request failed with code: " + String(httpCode));
    }
    
    http.end();
  } else {
    Serial.println("❌ Failed to initialize HTTP client for test");
  }
  
  Serial.println("🏁 Backend connection test completed");
}