# SX1509

This class interfaces with the SX1509 IO expander. It sits on the I2C bus and
data can be directed to the connected devices via its I2C address. Interrupts
from the devices can be fed back to the imp via the configured imp hardware pin.

## Class Usage

### Constructor: SX1509(*i2cBus, i2cAddress, interruptPin*)

The constructor requires the i2c bus, the address on that bus and the hardware pin to use for interrupts. These should all be configured before calling the constructor.

## Class Methods

### reset()

Write registers to default values

### bank(*gpio*)

Returns the register numbers for the bank that the given gpio is on

### setIrqEdges(*gpio, rising, falling*)

Configure whether edges trigger an interrupt for specified GPIO

### clearAllIrqs()

Resets all the IRQs

### getIrq()

Read all the IRQs as a single 16-bit bitmap

### setClock(*gpio, enable*)

Sets the clock

### setLEDDriver(*gpio, enable*)

Enable or disable the LED drivers

### setTimeOn(*gpio, value*)

Sets the *Time On* value for the LED register

### setIntensityOn(*gpio, value*)

Sets the *On Intensity* level LED register

### setOff(*gpio, value*)

Sets the *Time Off* value for the LED register

### setRiseTime(*gpio, value*)

Sets the *Rise Time* value for the LED register

### setFallTime(*gpio, value*)

Sets the *Fall Time* value for the LED register

### setPin(*gpio, level*)

Set or clear a selected GPIO pin, 0-16

### setDir(*gpio, output*)

Configure specified GPIO pin as input(0) or output(1)

### setInputBuffer(*gpio, enable*)

Enable or disable input buffers

### setOpenDrain(*gpio, enable*)

Enable or disable open drain

### setPullUp(*gpio, enable*)

Enable or disable internal pull up resistor for specified GPIO

### setPullDn(*gpio, enable*)

Enable or disable internal pull down resistor for specified GPIO

### setIrqMask(*gpio, enable*)

Configure whether specified GPIO will trigger an interrupt

### clearIrq(*gpio*)

Clear interrupt on specified GPIO

### getPin(*gpio*)

Get state of specified GPIO

### reboot()

Resets the device with a software reset

### setCallback(*gpio, callback*)

Configure which callback should be called for each pin transition

# ExpGPIO

This is a convenience class that simplifies the configuration of a IO Expander GPIO port.
You can use it in a similar manner to hardware.pin with two main differences:
1. There is a new pin type: LED_OUT, for controlling LED brightness (basically PWM_OUT with "breathing")
2. The pin events will include the pin state as the one parameter to the callback

## Class Usage

### Constructor: SX1509(*expander, gpio*)

Constructor requires the IO Expander class and the pin number to aquire

## Class Methods

### configure(*mode[, param]*)

Configure pin by passing in a *mode* constant. Supported modes are: DIGITAL_OUT, ExpGPIO.LED_OUT, DIGITAL_IN, or DIGITAL_IN_PULLUP. Optional *param* is either the initial state of the pin (defaults to 0 just like the imp) if configured as an output, or a callback function if mode is configured as an input.

### read()

Reads the status of the configured pin

### write(*state*)

Sets the state of the configured pin

### setIntensity(*intensity*)

Set the intensity of an LED OUT pin. Don't use for other pin types

### blink(*rampup, rampdown, intensityon[, intensityoff][, fade]*)

Set the blink rate of an LED OUT pin. Don't use for other pin types

### fade(*on[, risetime][, falltime]*)

Enable or disable fading (breathing)

# License

This code is licensed under the [MIT License](LICENSE).
