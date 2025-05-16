# NOIR System - LED and Buzzer Functionality

This document describes the LED and buzzer functionality added to the master device for the NOIR (Noise and Air Quality Monitoring System) project.

## LED Indicators

The system uses three LEDs to indicate different conditions:

1. **Green LED (Pin 4)**
   - **On**: Normal conditions (both sensors below thresholds)
   - **Off**: Warning condition detected (either sensor above threshold)

2. **Red LED (Pin 2)**
   - **Blinking**: Poor air quality detected (gas sensor value > threshold)
   - **Off**: Normal air quality

3. **Yellow LED (Pin 3)**
   - **Blinking**: High noise level detected (sound sensor value > threshold)
   - **Off**: Normal noise level

4. **Built-in LED (Pin 13)**
   - Used to indicate SPI communication activity

## Buzzer Functionality

The buzzer (Pin 5) provides audio alerts when warning conditions are detected:

- **Beeping Pattern**: Activates when either sensor exceeds its threshold (400ms on, ~600ms off)
- Can be silenced by pressing the button
- Silencing resets after 30 seconds or when conditions return to normal

### Buzzer Connection

- **Positive pin of buzzer**: Connect to BUZZER_PIN (Pin 5) on Arduino
- **Negative pin of buzzer**: Connect to GND (ground)

For active buzzer modules with three pins:
- VCC/+ pin: Connect to 5V on Arduino
- GND/- pin: Connect to GND on Arduino
- Signal pin: Connect to BUZZER_PIN (Pin 5) on Arduino

### Proteus-Specific Buzzer Configuration

For reliable buzzer operation in Proteus simulation:
- The buzzer is driven with a stronger signal pattern
- Multiple HIGH/LOW toggles are used to ensure the simulation registers the signal
- The startup routine includes a brief buzzer test
- The on-time has been extended to 400ms for better audibility

## Button Control

A button (Pin 6) is provided to silence the buzzer:

- When pressed, the buzzer is silenced until:
  1. Conditions return to normal, OR
  2. 30 seconds have passed (automatic timeout)

- Visual acknowledgment of button press is shown by flashing the green LED 3 times

## Threshold Values

- **Sound Threshold**: 600 (approx. 60% of full scale)
- **Gas Threshold**: 700 (approx. 70% of full scale)

## Status Reporting

The system provides detailed status information via the Serial Monitor:

- Raw sensor values and percentages
- Warning messages for each sensor when applicable
- Overall status summary
- Buzzer silencing and timeout events

## Implementation Notes

- LEDs blink at a rate of approximately 2 Hz (toggles every 250ms)
- Buzzer uses a short beep pattern (200ms on, ~800ms off)
- The system continuously monitors button state and updates outputs accordingly
- The built-in LED indicates SPI activity for debugging purposes
