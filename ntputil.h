#ifndef NTPUTIL_H
#define NTPUTIL_H

// Function declarations
void ntp_sync_thread(const char *ntp_server);
void rtc_write_ntp(int year, int month, int day, int hours, int minutes, int seconds);
void rtc_write_utc_time(time_t utc_time);
void rtc_sync_from_system_time(void);
void rtc_read();
#endif  // NTPUTIL_H

