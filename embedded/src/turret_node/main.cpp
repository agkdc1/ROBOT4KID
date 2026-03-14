/**
 * NL2Bot — Turret Node Firmware
 *
 * ESP32-CAM connecting to Hull's WiFi AP.
 * - Gunner camera MJPEG streaming
 * - Turret rotation motor control
 * - Barrel elevation servo
 * - VL53L0X Time-of-Flight rangefinder
 * - Firing mechanism (solenoid)
 * - UART communication from hull via slip ring
 */

#include <Arduino.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <esp_camera.h>
#include <ESP32Servo.h>
#include <Wire.h>
#include <VL53L0X.h>

#include "config.h"
#include "protocol.h"

// Camera pin definitions (same as hull — AI-Thinker ESP32-CAM)
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

AsyncWebServer server(HTTP_PORT);
AsyncWebServer streamServer(STREAM_PORT);
AsyncWebSocket ws("/ws");

Servo elevationServo;
VL53L0X tofSensor;

// State
int16_t currentTurretAngle = 0;   // degrees x10
int8_t  currentElevation = 0;     // degrees
uint16_t currentRange = 0;        // mm
bool fireRequested = false;

void setupCamera() {
    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM;
    config.pin_d1 = Y3_GPIO_NUM;
    config.pin_d2 = Y4_GPIO_NUM;
    config.pin_d3 = Y5_GPIO_NUM;
    config.pin_d4 = Y6_GPIO_NUM;
    config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM;
    config.pin_d7 = Y9_GPIO_NUM;
    config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = PCLK_GPIO_NUM;
    config.pin_vsync = VSYNC_GPIO_NUM;
    config.pin_href = HREF_GPIO_NUM;
    config.pin_sccb_sda = SIOD_GPIO_NUM;
    config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = PWDN_GPIO_NUM;
    config.pin_reset = RESET_GPIO_NUM;
    config.xclk_freq_hz = 20000000;
    config.pixel_format = PIXFORMAT_JPEG;

    if (psramFound()) {
        config.frame_size = FRAME_SIZE;
        config.jpeg_quality = JPEG_QUALITY;
        config.fb_count = 2;
    } else {
        config.frame_size = FRAMESIZE_SVGA;
        config.jpeg_quality = 16;
        config.fb_count = 1;
    }

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("Camera init failed: 0x%x\n", err);
    }
}

void setTurretMotor(int8_t speed) {
    int pwm = map(abs(speed), 0, 100, 0, 255);
    if (speed > 0) {
        ledcWrite(TURRET_MOTOR_IA, pwm);
        ledcWrite(TURRET_MOTOR_IB, 0);
    } else if (speed < 0) {
        ledcWrite(TURRET_MOTOR_IA, 0);
        ledcWrite(TURRET_MOTOR_IB, pwm);
    } else {
        ledcWrite(TURRET_MOTOR_IA, 0);
        ledcWrite(TURRET_MOTOR_IB, 0);
    }
}

void setElevation(int8_t degrees) {
    currentElevation = constrain(degrees, -10, 45);
    // Map -10..+45 to servo range (e.g., 80..135 degrees)
    int servoAngle = map(currentElevation, -10, 45, 80, 135);
    elevationServo.write(servoAngle);
}

void fireMechanism() {
    digitalWrite(FIRE_PIN, HIGH);
    delay(100);  // Solenoid pulse
    digitalWrite(FIRE_PIN, LOW);
    fireRequested = false;
}

void handleCommand(const TankCommand& cmd) {
    switch (cmd.type) {
        case CMD_TURRET: {
            // Turret rotation — convert angle difference to motor speed
            int16_t targetAngle = cmd.turret_angle;
            int16_t diff = targetAngle - currentTurretAngle;
            if (abs(diff) > 50) {  // Dead zone: 5 degrees
                int8_t speed = constrain(diff / 10, -100, 100);
                setTurretMotor(speed);
            } else {
                setTurretMotor(0);
            }
            currentTurretAngle = targetAngle;

            // Barrel elevation
            setElevation(cmd.barrel_elevation);
            break;
        }
        case CMD_FIRE:
            if (cmd.fire) {
                fireRequested = true;
            }
            break;
    }
}

void onWebSocketEvent(AsyncWebSocket *server, AsyncWebSocketClient *client,
                      AwsEventType type, void *arg, uint8_t *data, size_t len) {
    if (type == WS_EVT_DATA) {
        if (len == sizeof(TankCommand)) {
            TankCommand cmd;
            memcpy(&cmd, data, sizeof(TankCommand));
            if (validate_command(cmd)) {
                handleCommand(cmd);
            }
        }
    }
}

void sendStatusToHull() {
    TankStatus status;
    status.header = PACKET_HEADER;
    status.type = CMD_STATUS;
    status.heading = 0;  // Turret doesn't have its own IMU by default
    status.pitch = 0;
    status.roll = 0;
    status.range_mm = currentRange;
    status.battery_pct = 0;
    status.checksum = compute_checksum((const uint8_t*)&status, sizeof(TankStatus) - 1);
    Serial2.write((const uint8_t*)&status, sizeof(TankStatus));
}

void setup() {
    Serial.begin(115200);
    Serial2.begin(115200, SERIAL_8N1, HULL_UART_RX, HULL_UART_TX);

    // Connect to Hull's WiFi AP
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    Serial.printf("Connecting to %s", WIFI_SSID);
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(500);
        Serial.print(".");
        attempts++;
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("\nConnected! IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("\nWiFi connection failed!");
    }

    // Setup camera
    setupCamera();

    // Setup turret motor
    ledcAttach(TURRET_MOTOR_IA, PWM_FREQ, PWM_RES);
    ledcAttach(TURRET_MOTOR_IB, PWM_FREQ, PWM_RES);

    // Setup elevation servo
    elevationServo.attach(SERVO_ELEVATION_PIN, 500, 2400);
    setElevation(0);

    // Setup firing mechanism
    pinMode(FIRE_PIN, OUTPUT);
    digitalWrite(FIRE_PIN, LOW);

    // Setup ToF sensor
    Wire.begin(TOF_SDA, TOF_SCL);
    tofSensor.setTimeout(500);
    if (tofSensor.init()) {
        tofSensor.startContinuous();
        Serial.println("VL53L0X initialized");
    } else {
        Serial.println("VL53L0X init failed!");
    }

    // WebSocket
    ws.onEvent(onWebSocketEvent);
    server.addHandler(&ws);

    // Health endpoint
    server.on("/health", HTTP_GET, [](AsyncWebServerRequest *request) {
        request->send(200, "application/json", "{\"node\":\"turret\",\"status\":\"ok\"}");
    });

    // Status endpoint
    server.on("/status", HTTP_GET, [](AsyncWebServerRequest *request) {
        char buf[256];
        snprintf(buf, sizeof(buf),
            "{\"turret_angle\":%d,\"elevation\":%d,\"range_mm\":%u}",
            currentTurretAngle / 10, currentElevation, currentRange);
        request->send(200, "application/json", buf);
    });

    server.begin();
    streamServer.begin();
    Serial.println("Turret node ready.");
}

void loop() {
    // Read ToF sensor
    uint16_t reading = tofSensor.readRangeContinuousMillimeters();
    if (!tofSensor.timeoutOccurred()) {
        currentRange = reading;
    }

    // Check for commands from hull via UART
    if (Serial2.available() >= (int)sizeof(TankCommand)) {
        TankCommand cmd;
        Serial2.readBytes((uint8_t*)&cmd, sizeof(TankCommand));
        if (validate_command(cmd)) {
            handleCommand(cmd);
        }
    }

    // Handle fire request
    if (fireRequested) {
        fireMechanism();
    }

    // Send status to hull periodically
    static unsigned long lastStatus = 0;
    if (millis() - lastStatus > 100) {  // 10 Hz
        sendStatusToHull();
        lastStatus = millis();
    }

    // WebSocket cleanup
    ws.cleanupClients();

    delay(10);
}
