/*
 * NOIR System - Master with SPI and Sensor Data (AVR Assembly)
 * --------------------------------------------------------
 * This file is a required wrapper for the Arduino environment.
 * The actual code is in the NOIR_Master.S assembly file.
 * 
 * This program monitors sound and gas sensors, displays data
 * via serial communication and provides visual and audio alerts.
 * 
 * Note: All functions are implemented in assembly language.
 */

// The setup and loop functions are implemented in NOIR_Master.S
// Arduino will automatically link with them.

// This empty file is just a wrapper to make Arduino happy.
// No C/C++ code is needed here