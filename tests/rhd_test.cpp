#include <gtest/gtest.h>

extern "C" {
#include "rhd.h"
}

TEST(RHD, DupeUnsplit) {
  uint8_t a[] = {135, 42, 187, 91,  14,  239, 55,  178, 63, 105,
                 200, 33, 76,  162, 208, 4,   117, 88,  22, 195};
  for (int i = 0; i < sizeof(a); i++) {
    uint8_t ta;
    uint8_t tb;
    int ret = rhd_duplicate_bits(a[i]);
    rhd_unsplit_u16(ret, &ta, &tb);
    EXPECT_EQ(ta, a[i]);
  }
}

TEST(RHD, DuplicateBits) {
  int val[] = {0xAA, 0x55};
  int exp[] = {0xCCCC, 0x3333};
  for (int i = 0; i < sizeof(val) / sizeof(int); i++) {
    int ret = rhd_duplicate_bits(val[i]);
    EXPECT_EQ(ret, exp[i]);
  }
}

TEST(RHD, UnsplitMiso) {
  int val[] = {0xCCCC, 0x3333};
  int exp[] = {0xAA, 0x55};
  for (int i = 0; i < sizeof(val) / sizeof(int); i++) {
    uint8_t ret, dum;
    rhd_unsplit_u16(val[i], &ret, &dum);
    EXPECT_EQ(ret, exp[i]);
  }
}

int rw(uint16_t *tx_buf, uint16_t *rx_buf, size_t len) {
  // Changing these values will break the tests !
  rx_buf[0] = 0xAAAA;
  rx_buf[1] = 0x5555;
  return len;
}

TEST(RHD, RhdInit) {
  rhd_device_t dev;

  rhd_init(&dev, 0, rw);
  EXPECT_EQ(rhd_send(&dev, 0, 0), 1);

  rhd_init(&dev, 1, rw);
  EXPECT_EQ(rhd_send(&dev, 0, 0), 2);
}

TEST(RHD, RhdSendRaw) {
  rhd_device_t dev;
  rhd_init(&dev, 0, rw);
  int len = rhd_send_raw(&dev, 0xAA);
  EXPECT_EQ(dev.tx_buf[0], 0xAA);
  EXPECT_EQ(len, 1);

  rhd_init(&dev, 1, rw);
  len = rhd_send_raw(&dev, 0xAA);
  EXPECT_EQ(dev.tx_buf[0], 0xAA);
  EXPECT_EQ(len, 2);
}

TEST(RHD, RhdSend) {
  rhd_device_t dev;
  rhd_init(&dev, 0, rw);
  int len = rhd_send(&dev, 0xAA, 0x55);
  EXPECT_EQ(dev.tx_buf[0] & 0xFF00, (0xAA) << 8);
  EXPECT_EQ(dev.tx_buf[0] & 0xFF, 0x55);
  EXPECT_EQ(len, 1);

  rhd_init(&dev, 1, rw);
  len = rhd_send(&dev, 0xAA, 0x55);
  EXPECT_EQ(dev.tx_buf[0], 0xCCCC);
  EXPECT_EQ(dev.tx_buf[1], 0x3333);
  EXPECT_EQ(len, 2);
}

TEST(RHD, RhdRead) {
  rhd_device_t dev;
  rhd_init(&dev, 0, rw);
  int len = rhd_r(&dev, 0x0F, 0x55);
  EXPECT_EQ(dev.tx_buf[0] & 0xFF00, 0xCF00);
  EXPECT_EQ(dev.tx_buf[0] & 0xFF, 0x55);
  EXPECT_EQ(len, 1);
  EXPECT_EQ(dev.rx_buf[0], 0xAAAA);
  EXPECT_EQ(dev.rx_buf[1], 0x5555);

  rhd_init(&dev, 1, rw);
  len = rhd_r(&dev, 0x0F, 0x55);
  EXPECT_EQ(dev.tx_buf[0], 0xF0FF);
  EXPECT_EQ(dev.tx_buf[1], 0x3333);
  EXPECT_EQ(len, 2);
  EXPECT_EQ(dev.rx_buf[0], 0xAAAA);
  EXPECT_EQ(dev.rx_buf[1], 0x5555);
}

TEST(RHD, RhdWrite) {
  rhd_device_t dev;
  rhd_init(&dev, 0, rw);
  int len = rhd_w(&dev, 0x0F, 0x55);
  EXPECT_EQ(dev.tx_buf[0] & 0xFF00, 0x8F00);
  EXPECT_EQ(dev.tx_buf[0] & 0xFF, 0x55);
  EXPECT_EQ(len, 1);

  rhd_init(&dev, 1, rw);
  len = rhd_w(&dev, 0x0F, 0x55);
  EXPECT_EQ(dev.tx_buf[0], 0xC0FF);
  EXPECT_EQ(dev.tx_buf[1], 0x3333);
  EXPECT_EQ(len, 2);
}

TEST(RHD, RhdClearCalib) {
  rhd_device_t dev;
  rhd_init(&dev, 0, rw);
  int len = rhd_clear_calib(&dev);
  EXPECT_EQ(dev.tx_buf[0], 0b01101010 << 8);
  EXPECT_EQ(len, 1);

  rhd_init(&dev, 1, rw);
  len = rhd_clear_calib(&dev);
  EXPECT_EQ(dev.tx_buf[0], 0b0011110011001100);
  EXPECT_EQ(len, 2);
}

TEST(RHD, RhdSample) {
  rhd_device_t dev;
  rhd_init(&dev, 0, rw);
  int len = rhd_sample(&dev, 10);
  EXPECT_EQ(dev.sample_buf[20], 0xAA);
  EXPECT_EQ(dev.sample_buf[21], 0xAA | 0x1);
  EXPECT_EQ(dev.sample_buf[20 + 64], 0x55);
  EXPECT_EQ(dev.sample_buf[21 + 64], 0x55 | 0x1);
  EXPECT_EQ(len, 1);

  rhd_init(&dev, 1, rw);
  len = rhd_sample(&dev, 31);
  EXPECT_EQ(dev.sample_buf[62], 0xFF);
  EXPECT_EQ(dev.sample_buf[63], 0x00 | 0x1);
  EXPECT_EQ(dev.sample_buf[126], 0x00);
  EXPECT_EQ(dev.sample_buf[127], 0xFF | 0x1);
  EXPECT_EQ(len, 2);
}

TEST(RHD, RhdSampleAll) {
  extern const uint16_t RHD_ADC_CH_CMD[32];
  extern const uint16_t RHD_ADC_CH_CMD_DOUBLE[32];

  rhd_device_t dev;
  rhd_init(&dev, 0, rw);
  rhd_sample_all(&dev);
  EXPECT_EQ(dev.tx_buf[0], RHD_ADC_CH_CMD[0]);
  EXPECT_EQ(dev.sample_buf[1] & 0x1, 0); // Check channel 0 lsb
  EXPECT_EQ(dev.sample_buf[3] & 0x1, 1); // Check other channel lsb
  for (int i = 0; i < 32; i++) {         // Check all channel values
    EXPECT_EQ(dev.sample_buf[i * 2], 0xAA);
    EXPECT_EQ(dev.sample_buf[(i * 2) + 1] & 0xFE, 0xAA);
    EXPECT_EQ(dev.sample_buf[(i + 32) * 2], 0x55);
    EXPECT_EQ(dev.sample_buf[((i + 32) * 2) + 1], 0x55);
  }

  rhd_init(&dev, 1, rw);
  rhd_sample_all(&dev);
  EXPECT_EQ(dev.tx_buf[0], RHD_ADC_CH_CMD_DOUBLE[0]);
  EXPECT_EQ(dev.sample_buf[1] & 0x1, 0);
  EXPECT_EQ(dev.sample_buf[3] & 0x1, 1);
  for (int i = 0; i < 32; i++) {
    EXPECT_EQ(dev.sample_buf[i * 2], 0xFF);
    EXPECT_EQ(dev.sample_buf[(i * 2) + 1] & 0xFE, 0x00);
    EXPECT_EQ(dev.sample_buf[(i + 32) * 2], 0x00);
    EXPECT_EQ(dev.sample_buf[((i + 32) * 2) + 1], 0xFF);
  }
}