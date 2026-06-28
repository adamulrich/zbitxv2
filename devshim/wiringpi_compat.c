#include "wiringPi.h"
#include "wiringPiI2C.h"
#include "wiringSerial.h"

#include <errno.h>
#include <string.h>
#include <time.h>

#define MAX_PINS 128

static int pin_values[MAX_PINS];
static struct timespec start_time;
static int start_time_set = 0;

static void sleep_for(long nanoseconds) {
  struct timespec req;
  struct timespec rem;

  if (nanoseconds <= 0) {
    return;
  }

  req.tv_sec = nanoseconds / 1000000000L;
  req.tv_nsec = nanoseconds % 1000000000L;

  while (nanosleep(&req, &rem) == -1 && errno == EINTR) {
    req = rem;
  }
}

static void ensure_start_time(void) {
  if (start_time_set) {
    return;
  }

  clock_gettime(CLOCK_MONOTONIC, &start_time);
  start_time_set = 1;

  for (int i = 0; i < MAX_PINS; i++) {
    pin_values[i] = HIGH;
  }
}

int wiringPiSetup(void) {
  ensure_start_time();
  return 0;
}

int wiringPiISR(int pin, int edgeType, void (*function)(void)) {
  (void) pin;
  (void) edgeType;
  (void) function;
  ensure_start_time();
  return 0;
}

void pinMode(int pin, int mode) {
  (void) pin;
  (void) mode;
  ensure_start_time();
}

void pullUpDnControl(int pin, int pud) {
  (void) pin;
  (void) pud;
  ensure_start_time();
}

void digitalWrite(int pin, int value) {
  ensure_start_time();
  if (pin >= 0 && pin < MAX_PINS) {
    pin_values[pin] = value;
  }
}

int digitalRead(int pin) {
  ensure_start_time();
  if (pin >= 0 && pin < MAX_PINS) {
    return pin_values[pin];
  }

  return HIGH;
}

void delay(unsigned int howLong) {
  sleep_for((long) howLong * 1000000L);
}

void delayMicroseconds(unsigned int howLong) {
  sleep_for((long) howLong * 1000L);
}

unsigned int millis(void) {
  struct timespec now;
  time_t seconds;
  long nanoseconds;

  ensure_start_time();
  clock_gettime(CLOCK_MONOTONIC, &now);

  seconds = now.tv_sec - start_time.tv_sec;
  nanoseconds = now.tv_nsec - start_time.tv_nsec;
  if (nanoseconds < 0) {
    seconds -= 1;
    nanoseconds += 1000000000L;
  }

  return (unsigned int) (seconds * 1000L + nanoseconds / 1000000L);
}

int wiringPiI2CSetup(int devId) {
  ensure_start_time();
  return devId > 0 ? devId : 1;
}

int wiringPiI2CReadReg8(int fd, int reg) {
  (void) fd;
  (void) reg;
  ensure_start_time();
  return 0;
}

int wiringPiI2CWriteReg8(int fd, int reg, int data) {
  (void) fd;
  (void) reg;
  (void) data;
  ensure_start_time();
  return 0;
}

int serialOpen(const char *device, const int baud) {
  (void) device;
  (void) baud;
  ensure_start_time();
  return 1;
}

void serialClose(const int fd) {
  (void) fd;
}

void serialPutchar(const int fd, const unsigned char c) {
  (void) fd;
  (void) c;
}

void serialPuts(const int fd, const char *s) {
  (void) fd;
  (void) s;
}

int serialDataAvail(const int fd) {
  (void) fd;
  return 0;
}

int serialGetchar(const int fd) {
  (void) fd;
  return -1;
}

void serialFlush(const int fd) {
  (void) fd;
}
