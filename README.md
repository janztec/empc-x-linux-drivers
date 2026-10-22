# emPC-X & emVIEW-8T,12T,15T,15WT/X by Janz Tec AG

This script installs and configures Linux **Socket CAN** and **I2C_SSM** drivers 

## Installation Instructions:

**:heavy_exclamation_mark:  WARNING!! EXPERIMENTAL**

_create a backup copy of your CFast card/SSD before applying this driver installation script!_


**Step1:**

Install Debian or Ubuntu operating system from DVD (64bit recommended)

**Step 2:**
```
sudo bash
cd /tmp
wget https://raw.githubusercontent.com/janztec/empc-x-linux-drivers/master/install.sh -O install.sh
bash install-experimental.sh
```

## Configure can baud rate

The installer runs `empc-can-configbaudrate.sh` to select a baud rate for each CAN interface.

To change the rates later, execute the configuration script again:

```
sudo /usr/bin/empc-can-configbaudrate.sh
```

## Product Pages
https://www.janztec.com/en/products/embedded-computing/embedded-pc/empc-x/

https://www.janztec.com/en/products/embedded-computing/panel-pc/emview-8/

https://www.janztec.com/en/products/embedded-computing/panel-pc/emview-12/

https://www.janztec.com/en/products/embedded-computing/panel-pc/emview-15t/

https://www.janztec.com/en/products/embedded-computing/panel-pc/emview-15wt/
