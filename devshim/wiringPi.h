#ifndef DEVSHIM_WIRINGPI_H
#define DEVSHIM_WIRINGPI_H

#ifdef __cplusplus
extern "C" {
#endif

#define INPUT 0
#define OUTPUT 1

#define LOW 0
#define HIGH 1

#define PUD_OFF 0
#define PUD_DOWN 1
#define PUD_UP 2

#define INT_EDGE_SETUP 0
#define INT_EDGE_FALLING 1
#define INT_EDGE_RISING 2
#define INT_EDGE_BOTH 3

int wiringPiSetup(void);
int wiringPiISR(int pin, int edgeType, void (*function)(void));
void pinMode(int pin, int mode);
void pullUpDnControl(int pin, int pud);
void digitalWrite(int pin, int value);
int digitalRead(int pin);
void delay(unsigned int howLong);
void delayMicroseconds(unsigned int howLong);
unsigned int millis(void);

#ifdef __cplusplus
}
#endif

#endif
