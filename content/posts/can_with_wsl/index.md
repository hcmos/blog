---
title: "WSLでCAN-USBを使う"
date: 2024-06-23
categories: ["技術"]
tags: ["ロボット", "通信", "Linux"]
menu: main
---

### 環境
| 項目 | 値|
| ---- | ---- |
| WSL | バージョン2 |
| コンテナ | Ubuntu-22.04 |
| docker | docker for windows(Hyper-V) |

```
> wsl -v
WSL バージョン: 2.2.4.0
カーネル バージョン: 5.15.153.1-2
WSLg バージョン: 1.0.61
MSRDC バージョン: 1.2.5326
Direct3D バージョン: 1.611.1-81528511
DXCore バージョン: 10.0.26091.1-240325-1447.ge-release
Windows バージョン: 10.0.19045.4529
```

### はじめに
仮想マシンは便利ですが，外部機器との接続やネットワークの設定が面倒だということで疎遠になっている人が多いと思います．
この記事では，CAN-USB変換機をwsl2で使えるようにしたので共有します．  
結構簡単なことなのですが，意外と他言語含めて情報が無いんですよね．ということで書きました．

### 使用機器
[SH-C30A](https://www.deshide.com/product-details.html?pid=384242&_t=1671089557)
というものを買いました．  
Amazonで三千円くらいと電子工作している人からするとぼったくり価格なのですが，stm32で簡単にDFUモードで立ち上げられたりとか，終端抵抗のスイッチがあったりと
便利そうなのでこれにしました．  

ドキュメントには「linuxではドライバは要らないよ」と書いてあったのですが，それは一般的なlinuxカーネルを使用している場合です．  
確認のため，ネイティブインストールされたlinuxで接続したら，[gs_usb](https://github.com/torvalds/linux/blob/master/drivers/net/can/usb/gs_usb.c)
というものを使用していることが分かりました．

### USB機器のバインド
windowsのデバイスマネージャーで認識していることを確認します．
{{<figure src="./devicemanager.png" alt="デバイスマネージャー" width="50%">}}  

#### usbipd
[microsoftのページ](https://learn.microsoft.com/ja-jp/windows/wsl/connect-usb)
に詳しく書かれています．  

接続されているデバイスのバスIDを調べます．  
| ステータスが`Shared`になっているのは気にしないでください．一度，attachしたら戻らなくなりました，実際には共有されていません．
```PowerShell
> usbipd list
BUSID  VID:PID    DEVICE                                                        STATE
9-4    1d50:606f  candleLight USB to CAN adapter, candleLight firmware upgr...  Shared
```

attachします．
```PowerShell
> usbipd attach --wsl --busid <busid>
```
使い終わったらdetachしてホストに返してあげましょう． `usbipd detach --busid <busid>`

#### コンテナ側
USBデバイスの一覧にあることを確認します．
```bash
$ lsusb
Bus 001 Device 002: ID 1d50:606f OpenMoko, Inc. Geschwister Schneider CAN adapter
```

### カーネルのビルド
- [このgithubイシュー](https://github.com/microsoft/WSL/issues/5533)が参考になりました．  

このままではsocketCANとして扱えないので，ドライバを有効化します．  
そのまえに一応wslのバックアップをしておきましょう．  
| 結構ファイルサイズが大きくなります，私のは20GBくらいになりました．
```PowerShell
# windows側
> wsl --export <コンテナのディストリビューション名> hoge-path/hoge.tar
```

では始めましょう．コンテナ上で行ってください．  
wslのカーネルソースをcloneして使用するカーネルのバージョンにブランチを切ります．
```bash
$ git clone https://github.com/microsoft/WSL2-Linux-Kernel
$ cd WSL2-Linux-Kernel
$ git checkout `uname -r`
```
現在使用しているconfigファイルを持ってきます．
```bash
$ cat /proc/config.gz | gunzip > .config
```
#### コンフィグの設定
GUIからコンフィグを設定します．
```bash
$ make prepare modules_prepare
$ make menuconfig
```
こんな感じの画面が出てきたら，  
Networking suppport ---> CAN bus subsystem support をMにします．  
| ちなみに，カーネル内に直接ビルドするのが(Y)でモジュールとしてビルドするのが(M)になります．  
{{<figure src="./guiconfig.png" alt="デバイスマネージャー" width="50%">}}  

CAN Device Drivers --->  
からvcanとslcanはMにしておきます．  
CAN USB interfaces --->  
から使用するドライバをMにしておきます．  

`.config`というデフォルトの名前で保存しておきます．  

---
これでも良いんですが，直接`.config`を開いても良いです．というか，そっちの方が楽です．  
canの設定があるところを見つけて編集します．こちらはインタフェースの設定が略称で書いてあるので分かりやすいです．
```vim
CONFIG_CAN=m
CONFIG_CAN_RAW=m
CONFIG_CAN_BCM=m
CONFIG_CAN_GW=m
# CONFIG_CAN_J1939 is not set
# CONFIG_CAN_ISOTP is not set

#
# CAN Device Drivers
#
CONFIG_CAN_VCAN=m
# CONFIG_CAN_VXCAN is not set
CONFIG_CAN_SLCAN=m
CONFIG_CAN_DEV=m
CONFIG_CAN_CALC_BITTIMING=y
# CONFIG_CAN_KVASER_PCIEFD is not set
# CONFIG_CAN_C_CAN is not set
# CONFIG_CAN_CC770 is not set
# CONFIG_CAN_IFI_CANFD is not set
# CONFIG_CAN_M_CAN is not set
# CONFIG_CAN_PEAK_PCIEFD is not set
# CONFIG_CAN_SJA1000 is not set
# CONFIG_CAN_SOFTING is not set

#
# CAN USB interfaces
#
# CONFIG_CAN_8DEV_USB is not set
# CONFIG_CAN_EMS_USB is not set
# CONFIG_CAN_ESD_USB2 is not set
# CONFIG_CAN_ETAS_ES58X is not set
CONFIG_CAN_GS_USB=m
# CONFIG_CAN_KVASER_USB is not set
# CONFIG_CAN_MCBA_USB is not set
# CONFIG_CAN_PEAK_USB is not set
# CONFIG_CAN_UCAN is not set
# end of CAN USB interfaces

# CONFIG_CAN_DEBUG_DEVICES is not set
# end of CAN Device Drivers
```
`CONFIG_LOCALVERSION="-microsoft-standard-WSL2"`を変えれば`uname -r`したときのカーネル名が変えられます．
素晴らしい名前を付けてあげましょう．

---
必要なものをインストールしてコンパイルします．
```bash
$ sudo apt update
$ sudo apt install -y build-essential flex bison libssl-dev libelf-dev dwarves libncurses-dev
$ make -j 10
$ make modules_install
$ make install
```

正常終了したら生成されたカーネルをwindowsの方にもっていきます．
```bash
$ cp arch/x86/boot/bzImage /mnt/c/Users/<ユーザー名>/wsl_kernel
```

windows側で`.wslconfig`を以下のように編集します．
```PowerShell
# windows側
[wsl2]
kernel = C:\\Users\\<ユーザー名>\\wsl_kernel
```
wslを再起動します．
```PowerShell
# windows側
> wsl --shutdown
> wsl
```

### 通信する
再起動しましたので，usbipdでattachしなおします．  

そして，ドライバが認識していることを確認します．
```bash
$ dmesg
・
・
・
[ 1108.916314] usb 1-1: New USB device found, idVendor=1d50, idProduct=606f, bcdDevice= 0.00
[ 1108.916318] usb 1-1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[ 1108.916319] usb 1-1: Product: candleLight USB to CAN adapter
[ 1108.916320] usb 1-1: Manufacturer: bytewerk
[ 1108.916321] usb 1-1: SerialNumber: 0032002B5546570C20363531
[ 1108.933221] CAN device driver interface
[ 1108.936401] gs_usb 1-1:1.0: Configuring for 1 interfaces
[ 1108.937060] usbcore: registered new interface driver gs_usb
```
```bash
$ ip a
・
・
・
3: can0: <NOARP,ECHO> mtu 16 qdisc noop state DOWN group default qlen 10
    link/can
```

使用するにはカーネルモジュールをロードする必要があります．
また，デバイスの状態を有効化します．
```bash
$ sudo modprobe can
$ sudo modprobe can-raw
$ sudo modprobe vcan

$ sudo ip link set can0 type can bitrate <ボーレート>
$ sudo ip link set can0 up
```

candumpで受信したパケットを確認します．  
何かを繋いで以下のように表示されればOKです．
```bash
$ sudo apt install can-utils

$ candump can0 -x
can0  RX - -  000   [8]  00 00 00 00 00 00 00 00
```

### dockerコンテナで使用する
- [参考ページ](https://www.systec-electronic.com/en/demo/blog/article/news-socketcan-docker-the-solution)

頑張ったけどできませんでした．．．  
`--network=host`にしたり`vcan`を使用したりしましたが，認識しませんでした．また挑戦し，出来たら更新したいと思います．
