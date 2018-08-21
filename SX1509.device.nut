// MIT License
//
// Copyright 2013-8 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE


// This class interfaces with the SX1509 IO expander. It sits on the I2C bus and
// data can be directed to the connected devices via its I2C address. Interrupts
// from the devices can be fed back to the imp via the configured imp hardware pin.
class SX1509 {

    //Private variables
    _i2c       = null;
    _addr      = null;
    _callbacks = null;
    _int_pin   = null;

    // I/O Expander internal registers
    static BANK_A = {   REGDATA    = 0x11,
                        REGDIR     = 0x0F,
                        REGPULLUP  = 0x07,
                        REGPULLDN  = 0x09,
                        REGINTMASK = 0x13,
                        REGSNSHI   = 0x16,
                        REGSNSLO   = 0x17,
                        REGINTSRC  = 0x19,
                        REGINPDIS  = 0x01,
                        REGOPENDRN = 0x0B,
                        REGLEDDRV  = 0x21,
                        REGCLOCK   = 0x1E,
                        REGMISC    = 0x1F,
                        REGRESET   = 0x7D };

    static BANK_B = {   REGDATA    = 0x10,
                        REGDIR     = 0x0E,
                        REGPULLUP  = 0x06,
                        REGPULLDN  = 0x08,
                        REGINTMASK = 0x12,
                        REGSNSHI   = 0x14,
                        REGSNSLO   = 0x15,
                        REGINTSRC  = 0x18,
                        REGINPDIS  = 0x00,
                        REGOPENDRN = 0x0A,
                        REGLEDDRV  = 0x20,
                        REGCLOCK   = 0x1E,
                        REGMISC    = 0x1F,
                        REGRESET   = 0x7D };

    // Class constants, the constants defined here are only available within
    // this class
    function __statics__() {
        const ERR_NO_DEVICE = "The device at I2C address 0x%02x is disabled.";
        const ERR_I2C_READ = "I2C Read Failure. Device: 0x%02x Register: 0x%02x";
        const ERR_BAD_TIMER = "You have to start %s with an interval and callback";
        const ERR_WRONG_DEVICE = "The device at I2C address 0x%02x is not a %s.";
    }

    // Constructor requires the i2c bus, the address on that bus and the hardware pin to use for interrupts
    // These should all be configured before use here.
    constructor(i2c, address, int_pin) {
        _i2c  = i2c;
        _addr = address;
        _callbacks = [];
        _callbacks.resize(16, null);
        _int_pin = int_pin;

        reset();
        clearAllIrqs();
    }


    // ---- Low level functions ----

    // Reads a single byte from a registry
    function readReg(register) {
        local data = _i2c.read(_addr, format("%c", register), 1);
        if (data == null) {
            server.error(format(ERR_I2C_READ, _addr, register));
            return -1;
        }
        return data[0];
    }

    // Writes a single byte to a registry
    function writeReg(register, data) {
        _i2c.write(_addr, format("%c%c", register, data));
        // server.log(format("Setting device 0x%02X register 0x%02X to 0x%02X", _addr, register, data));
    }

    // Changes one bit out of the selected register (byte)
    function writeBit(register, bitn, level) {
        local value = readReg(register);
        value = (level == 0) ? (value & ~(1<<bitn)) : (value | (1<<bitn));
        writeReg(register, value);
    }

    // Writes a registry but masks specific bits. Similar to writeBit but for multiple bits.
    function writeMasked(register, data, mask) {
        local value = readReg(register);
        value = (value & ~mask) | (data & mask);
        writeReg(register, value);
    }

    // set or clear a selected GPIO pin, 0-16
    function setPin(gpio, level) {
        writeBit(bank(gpio).REGDATA, gpio % 8, level ? 1 : 0);
    }

    // configure specified GPIO pin as input(0) or output(1)
    function setDir(gpio, output) {
        writeBit(bank(gpio).REGDIR, gpio % 8, output ? 0 : 1);
    }

    // enable or disable input buffers
    function setInputBuffer(gpio, enable) {
        writeBit(bank(gpio).REGINPDIS, gpio % 8, enable ? 0 : 1);
    }

    // enable or disable open drain
    function setOpenDrain(gpio, enable) {
        writeBit(bank(gpio).REGOPENDRN, gpio % 8, enable ? 1 : 0);
    }

    // enable or disable internal pull up resistor for specified GPIO
    function setPullUp(gpio, enable) {
        writeBit(bank(gpio).REGPULLUP, gpio % 8, enable ? 1 : 0);
    }

    // enable or disable internal pull down resistor for specified GPIO
    function setPullDn(gpio, enable) {
        writeBit(bank(gpio).REGPULLDN, gpio % 8, enable ? 1 : 0);
    }

    // configure whether specified GPIO will trigger an interrupt
    function setIrqMask(gpio, enable) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, enable ? 0 : 1);
    }

    // clear interrupt on specified GPIO
    function clearIrq(gpio) {
        writeBit(bank(gpio).REGINTMASK, gpio % 8, 1);
    }

    // get state of specified GPIO
    function getPin(gpio) {
        return ((readReg(bank(gpio).REGDATA) & (1<<(gpio%8))) ? 1 : 0);
    }

    // resets the device with a software reset
    function reboot() {
        writeReg(bank(0).REGRESET, 0x12);
        writeReg(bank(0).REGRESET, 0x34);
    }

    // configure which callback should be called for each pin transition
    function setCallback(gpio, _callback) {
        _callbacks[gpio] = _callback;

        // Initialize the interrupt Pin
        _int_pin.configure(DIGITAL_IN_PULLUP, fire_callback.bindenv(this));
    }

    // finds and executes the callback after the irq pin (pin 1) fires
    function fire_callback() {
        local irq = getIrq();
        clearAllIrqs();
        for (local i = 0; i < 16; i++){
            if ( (irq & (1 << i)) && (typeof _callbacks[i] == "function")){
                _callbacks[i](getPin(i));
            }
        }
    }


    // ---- High level functions ----


    // Write registers to default values
    function reset(){
        writeReg(BANK_A.REGDIR, 0xFF);
        writeReg(BANK_A.REGDATA, 0xFF);
        writeReg(BANK_A.REGPULLUP, 0x00);
        writeReg(BANK_A.REGPULLDN, 0x00);
        writeReg(BANK_A.REGINTMASK, 0xFF);
        writeReg(BANK_A.REGSNSHI, 0x00);
        writeReg(BANK_A.REGSNSLO, 0x00);

        writeReg(BANK_B.REGDIR, 0xFF);
        writeReg(BANK_B.REGDATA, 0xFF);
        writeReg(BANK_B.REGPULLUP, 0x00);
        writeReg(BANK_B.REGPULLDN, 0x00);
        writeReg(BANK_B.REGINTMASK, 0xFF);
        writeReg(BANK_B.REGSNSHI, 0x00);
        writeReg(BANK_B.REGSNSLO, 0x00);
    }

    // Returns the register numbers for the bank that the given gpio is on
    function bank(gpio){
        return (gpio > 7) ? BANK_B : BANK_A;
    }

    // configure whether edges trigger an interrupt for specified GPIO
    function setIrqEdges(gpio, rising, falling) {
        local bank = bank(gpio);
        gpio = gpio % 8;
        local mask = 0x03 << ((gpio & 3) << 1);
        local data = (2*falling + rising) << ((gpio & 3) << 1);
        writeMasked(gpio >= 4 ? bank.REGSNSHI : bank.REGSNSLO, data, mask);
    }

    // Resets all the IRQs
    function clearAllIrqs() {
        writeReg(BANK_A.REGINTSRC,0xff);
        writeReg(BANK_B.REGINTSRC,0xff);
    }

    // Read all the IRQs as a single 16-bit bitmap
    function getIrq(){
        return ((readReg(BANK_B.REGINTSRC) & 0xFF) << 8) | (readReg(BANK_A.REGINTSRC) & 0xFF);
    }

    // sets the clock
    function setClock(gpio, enable) {
        writeReg(bank(gpio).REGCLOCK, enable ? 0x50 : 0x00); // 2mhz internal oscillator
    }

    // enable or disable the LED drivers
    function setLEDDriver(gpio, enable) {
        writeBit(bank(gpio).REGLEDDRV, gpio & 7, enable ? 1 : 0);
        writeReg(bank(gpio).REGMISC, 0x70); // Set clock to 2mhz / (2 ^ (1-1)) = 2mhz, use linear fading
    }

    // sets the Time On value for the LED register
    function setTimeOn(gpio, value) {
        writeReg(gpio<4 ? 0x29+gpio*3 : 0x35+(gpio-4)*5, value)
    }

    // sets the On Intensity level LED register
    function setIntensityOn(gpio, value) {
        writeReg(gpio<4 ? 0x2A+gpio*3 : 0x36+(gpio-4)*5, value)
    }

    // sets the Time Off value for the LED register
    function setOff(gpio, value) {
        writeReg(gpio<4 ? 0x2B+gpio*3 : 0x37+(gpio-4)*5, value)
    }

    // sets the Rise Time value for the LED register
    function setRiseTime(gpio, value) {
        if (gpio % 8 < 4) return; // Can't do all pins
        writeReg(gpio<12 ? 0x38+(gpio-4)*5 : 0x58+(gpio-12)*5, value)
    }

    // sets the Fall Time value for the LED register
    function setFallTime(gpio, value) {
        if (gpio % 8 < 4) return; // Can't do all pins
        writeReg(gpio<12 ? 0x39+(gpio-4)*5 : 0x59+(gpio-12)*5, value)
    }
}