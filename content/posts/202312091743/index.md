---
title: "ラズパイでロボット制御!"
date: 2023-12-09
categories: ["技術"]
tags: ["ロボット", "ラズパイ"]
menu: main
---

## この記事は
...

### 環境
| 項目 | 値|
| ---- | ---- |
| ラズパイ | 4B 4GB |
| ROS | ROS 2 humble |
| 開発環境 | Ubuntu22 |

### ROS
とかのパソコン環境を使いたいけど，GPIOも使いたいってことが普通にあると思います．ロボコンではマイコンで読んだ値をパソコンに送ったりして使うのですが，小規模なものでは面倒です．mROSやjetsonを使えばよいのかもしれませんが，簡単にグラフィカルな環境を安価に手に入れるためにラズパイは最適です．起動メディアを持ち歩けば，ハードウェアを変えずに自前の環境で開発できます．  

### USBブート
2020年12月以降のブートローダが入っているラズパイは最初からUSBブートが出来るらしいですが，私のはそうでなかったので，  
TFカードにRaspberryPi OSを入れて`raspi-config`からUSBブートを真にしときました．一応ブートローダも更新しときました．  
起動後は諸所のセットアップ．詳しくは[こちら](https://qiita.com/HirohitoHigashi/items/7b57781a8a4874012d3d)に書かれてます．

### モータを回す準備
差動二輪のロボットを研究用に作りたかったので，少なくとも二つのモータを回す必要があります．  
といってもMDを一から作るなどの技量はないし，しっかりとした既製品を買うお金もないので，[M3508](https://store.dji.com/jp/product/rm-m3508-p19-brushless-dc-gear-motor?vid=32501)と[C620](https://store.dji.com/jp/product/rm-c620-brushless-dc-motor-speed-controller?vid=32491)を使いました．
CANが使いたいので，こんな感じのハット基板を作りました．
{{<figure src="./IMG_4998.JPG" alt="ハット基板" width="50%">}}
コントローラはmcp2515で，spiから変換しています．ドライバはlinuxに書かれています．[mcp251x.c](https://github.com/torvalds/linux/blob/master/drivers/net/can/spi/mcp251x.c)

### ロボットに組み込む
ロボットはこんな感じのものを作りました．ラズパイの右に載ってるのは電源基板です．
{{<figure src="./IMG_5075.JPG" alt="ロボット" width="50%">}}

モータの目標値を計画する必要があります．差動二輪の並進・角速度は以下の方程式で計算できるので，
{{<figure src="./20190630203403.png" alt="運動学モデル" width="50%">}}
駆動輪の角速度に解いてやればよいです．
{{<figure src="./IMG_E5272.JPG" alt="逆運動学モデル" width="30%">}}
こいつを位置のPDコントローラで追従させます．

### 動作
https://youtube.com/shorts/hrbsJN5baHw?feature=share  
最初の動作としては上出来でしょう．(軸間距離長すぎだろ...)  
ジョイコンで操作しています．

#### IMU
をi2cから読んでみました．値がたまに飛んでますが，プルアップ抵抗の値変更とシールドケーブルにしたら直りました．  
https://youtube.com/shorts/g2Cg93idGa0?feature=share  

#### そこから
ハード・ソフト共にブラッシュアップし，このようになりました．(手動操縦ではありませんが)  
https://youtube.com/shorts/xhwst5pH3FI?feature=share  

### まとめ
以上のように簡単なロボット制御ならラズパイだけで出来ます．このハット基板以上にもPWM(4チャンネルくらい)使えたりします．  
デプロイ環境はubuntuでは重いので，RaspberryPi OS+ROSが良いと思います．  
ロボット制御したいけどハードウェア頑張りたくないって人は良いかもしれません．  
