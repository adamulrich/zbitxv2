#ifndef DEVSHIM_WIRINGPI_I2C_H
#define DEVSHIM_WIRINGPI_I2C_H

#ifdef __cplusplus
extern "C" {
#endif

int wiringPiI2CSetup(int devId);
int wiringPiI2CReadReg8(int fd, int reg);
int wiringPiI2CWriteReg8(int fd, int reg, int data);

#ifdef __cplusplus
}
#endif

#endif
