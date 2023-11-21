/** @file rhd.h
 *
 * @brief RHD C Driver header file
 *
 * @par
 * COPYRIGHT NOTICE: (c) 2023 SBIOML. All rights reserved.
 */

#ifndef RHD2000_H
#define RHD2000_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// -----------

/**
 * @brief RHD2164 Read Write function typedef.
 * When called, it must send out w_buf while reading into r_buf.
 * The driver uses @ref rhd_device_t's rx_buf and tx_buf.
 *
 * @param tx_buf write buffer
 * @param rx_buf receive buffer
 * @param len number of 16-bit values to transfer.
 *
 * @returns int : Return code
 */
typedef int (*rhd_rw_t)(uint16_t *tx_buf, uint16_t *rx_buf, size_t len);

typedef struct {
  rhd_rw_t rw;
  uint16_t tx_buf[2];
  uint16_t rx_buf[2];
  bool double_bits;
  uint8_t sample_buf[128];
} rhd_device_t;

typedef enum {
  ADC_CFG = 0,
  SUPPLY_SENS_ADC_BUF_BIAS = 1,
  MUX_BIAS_CURR = 2,
  MUX_LOAD_TEMP_SENS_AUX_DIG_OUT = 3,
  ADC_OUT_FMT_DPS_OFF_RMVL = 4,
  IMP_CHK_CTRL = 5,
  IMP_CHK_DAC = 6,
  IMP_CHK_AMP_SEL = 7,
  AMP_BW_SEL_0 = 8,
  AMP_BW_SEL_1 = 9,
  AMP_BW_SEL_2 = 10,
  AMP_BW_SEL_3 = 11,
  AMP_BW_SEL_4 = 12,
  AMP_BW_SEL_5 = 13,
  IND_AMP_PWR_0 = 14,
  IND_AMP_PWR_1 = 15,
  IND_AMP_PWR_2 = 16,
  IND_AMP_PWR_3 = 17,
  IND_AMP_PWR_4 = 18,
  IND_AMP_PWR_5 = 19,
  IND_AMP_PWR_6 = 20,
  IND_AMP_PWR_7 = 21,
  INTAN_0 = 40,
  INTAN_1 = 41,
  INTAN_2 = 42,
  INTAN_3 = 43,
  INTAN_4 = 44,
  MISO_A_B = 59,
  DIE_REV = 60,
  UNI_BIPLR_AMPS = 61,
  NB_AMP = 62,
  CHIP_ID = 63,
} rhd_reg_t;

/**
 * @brief Initialize RHD device driver
 *
 * @param dev pointer to rhd_device_t instance
 * @param mode true if using hardware flipflop strategy, false otherwise.
 * @param rw pointer to the read/write function.
 * This is how RHD2164 driver bridges to the hardware.
 * Refer to @ref rhd_rw_t's inline documentation.
 *
 * @return int SPI communication return code
 */
int rhd_init(rhd_device_t *dev, bool mode, rhd_rw_t rw);

/**
 * @brief Setup RHD device with sensible defaults
 *
 * @param dev pointer to rhd_device_t instance
 * @return int SPI communication return code
 */
int rhd_setup(rhd_device_t *dev);

/**
 * @brief Send raw data. This function, unlike `rhd_send`, does not double bits.
 * It should only be used for highly optimized situations where `val` is
 * pre-doubled, for example at compile-time.
 *
 * @param dev pointer to rhd_device_t instance
 * @param val value to send that is put in dev->tx_buf[0]
 * @return int SPI communication return code
 */
int rhd_send_raw(rhd_device_t *dev, uint16_t val);

/**
 * @brief Send data. Unlike rhd_r and rhd_w, this function does not set bits
 * [7:6] of reg. It does double the bits of `reg` and `val` if
 * `dev->double_bits` is true.
 *
 * @param dev pointer to rhd_device_t instance
 * @param reg register to read, member of rhd_reg_t enum
 * @param val value to send
 * @return int SPI communication return code
 */
int rhd_send(rhd_device_t *dev, uint16_t reg, uint16_t val);

/**
 * @brief Read RHD register
 * dev->tx_buf's content is overwritten with the commands.
 * dev->rx_buf contains the received values.
 *
 * @param dev pointer to rhd_device_t instance
 * @param reg register to read, member of rhd_reg_t enum
 * @return int SPI communication return code
 */
int rhd_r(rhd_device_t *dev, uint16_t reg, uint16_t val);

/**
 * @brief Write RHD register
 * dev->tx_buf's content is overwritten with the commands.
 *
 * @param dev pointer to rhd_device_t instance
 * @param reg Register to write to
 * @param val Value to write into register
 * @return int SPI return code
 */
int rhd_w(rhd_device_t *dev, uint16_t reg, uint16_t val);

/**
 * @brief Sample a single RHD channel.
 * dev->tx_buf's content is overwritten with the commands.
 * dev->sample_buf is written to at the channel's index.
 *
 * @param dev pointer to rhd_device_t instance
 * @param ch channel number to sample (0-31)
 * @return int SPI return code
 */
int rhd_sample(rhd_device_t *dev, uint8_t ch);

/**
 * @brief Run RHD calibration routine
 *
 * @param dev pointer to rhd_device_t instance
 * @return int SPI return code
 */
int rhd_calib(rhd_device_t *dev);

/**
 * @brief Clear RHD calibration
 *
 * @param dev pointer to rhd_device_t instance
 * @return int SPI return code
 */
int rhd_clear_calib(rhd_device_t *dev);

/**
 * @brief Sequentially sample all RHD channels.
 * The values are saved into dev->sample_buf.
 * Channel 0's LSb is set to 0, while all others are set to 1.
 *
 * @param dev pointer to rhd_device_t instance
 */
void rhd_sample_all(rhd_device_t *dev);

/**
 * @brief Decode rx'd bytes in dev->rx_buf to dev->sample_buf
 *
 * @param val 8-bit value to double every bit
 * @return int the 16-bit value with duplicate bits.
 */
int rhd_get_val_from_rx(rhd_device_t *dev);

/**
 * @brief Decode rx'd bytes in dev->rx_buf to dev->sample_buf
 *
 * @param ch channel of the sample [0-63] in dev->rx_buf
 */
void rhd_get_samples_from_rx(rhd_device_t *dev, uint16_t ch);

/**
 * @brief Duplicate the bits of a value.
 * It is assumed to be an 8-bits value.
 * For example, 0b01010011 becomes 0b0011001100001111
 *
 * @param val 8-bit value to double every bit
 * @return int the 16-bit value with duplicate bits.
 */
int rhd_duplicate_bits(uint8_t val);

/**
 * @brief Unsplit SPI DDR flip-flopped data
 *
 * @param data source data as 0bxyxy xyxy xyxy xyxy
 * @param a destination 8-bit data as 0bxxxx xxxx
 * @param b destination 8-bit data as 0byyyy yyyy
 */
void rhd_unsplit_u16(uint16_t data, uint8_t *a, uint8_t *b);

#endif /* RHD_H */

/*** end of file ***/