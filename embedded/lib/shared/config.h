#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration
#define WIFI_SSID     "TANK_CTRL"
#define WIFI_PASSWORD "tank1234"
#define WIFI_CHANNEL  1

// Hull Node IP (AP mode)
#define HULL_IP       "192.168.4.1"
#define TURRET_IP     "192.168.4.2"

// Server ports
#define HTTP_PORT     80
#define STREAM_PORT   81

// --- Hull Node Pin Mapping ---
#ifdef HULL_NODE
  // L9110 Motor Driver - Left Track
  #define MOTOR_L_IA    12
  #define MOTOR_L_IB    13

  // L9110 Motor Driver - Right Track
  #define MOTOR_R_IA    14
  #define MOTOR_R_IB    15

  // MPU6050 I2C
  #define I2C_SDA       2
  #define I2C_SCL       4

  // UART to Turret (via slip ring)
  #define TURRET_UART_TX 1
  #define TURRET_UART_RX 3
#endif

// --- Turret Node Pin Mapping ---
#ifdef TURRET_NODE
  // Barrel elevation servo
  #define SERVO_ELEVATION_PIN 2

  // Turret rotation motor (L9110 single channel)
  #define TURRET_MOTOR_IA    12
  #define TURRET_MOTOR_IB    13

  // Firing mechanism (solenoid/relay)
  #define FIRE_PIN           14

  // VL53L0X ToF I2C
  #define TOF_SDA            15
  #define TOF_SCL            4

  // UART from Hull (via slip ring)
  #define HULL_UART_TX       1
  #define HULL_UART_RX       3
#endif

// --- Train Node Pin Mapping ---
#ifdef TRAIN_NODE
  // DRV8833 Motor Driver - single channel for drive
  #define MOTOR_AIN1    12
  #define MOTOR_AIN2    13

  // Horn (buzzer)
  #define HORN_PIN      14

  // LED headlight/taillight
  #define LED_HEAD_PIN  15
  #define LED_TAIL_PIN  2

  // WiFi AP mode
  #define TRAIN_WIFI_SSID     "TRAIN_CTRL"
  #define TRAIN_WIFI_PASSWORD "train1234"
  #define TRAIN_IP            "192.168.4.1"
#endif

// Motor PWM settings
#define PWM_FREQ     5000
#define PWM_RES      8     // 8-bit: 0-255

// Camera settings
#define FRAME_SIZE   FRAMESIZE_VGA   // 640x480
#define JPEG_QUALITY 12              // 0-63 (lower = better quality)

#endif // CONFIG_H
