call C:\Programming\oss-cad-suite\environment.bat
iceprog -e 128 & :: Erases first 128 bytes to force a reset
iceprog -d i:0x0403:0x6014 fpga_cart.bin
iceprog -d i:0x0403:0x6014 -o 1M src/gb/rom.gbc
