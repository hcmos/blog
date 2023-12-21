---
title: "ROSトピックロガーを設置する"
date: 2023-12-22
categories: ["技術"]
tags: ["ロボコン", "ROS", "Linux"]
menu: main
---

## この記事は
[学ロボ Advent Calendar 2023](https://adventar.org/calendars/8926) の22日目  
[金沢工業大学 Advent Calendar 2023](https://qiita.com/advent-calendar/2023/kit-calendar) の22日目  
です．  
学ロボのアドカレで，MD製作欲が大きくなってます(なお当人は無知)．電子工作界隈って何かアクティブで良いですよね．  

ロボコン寄りの記事になってます(ｽﾐﾏｾﾝ)．

### 環境
| 項目 | 値|
| ---- | ---- |
| ROS | ROS 2 humble |
| 開発環境 | Ubuntu22(wsl2) |
| docker | docker for windows(Hyper-V) |

### 何がしたい?
ロボットの吐き出したデータをログに取って表示するって無限に必要だと思います．予定したタスクがなされてるか，制御系の性能はどれほどか，など．簡単なものだと受信したデータをcsvに入れてエクセルでプロットするとか．まあそれも面倒です．  
チームで行うには共有が楽で，でもセキュアで何よりデータが消滅しないものが必要です．  
2022年に上位コンピュータ+ROSを導入してから少しそこが楽になりました．しかし，皆が共通に使っているものはありません．ということでまずはROSトピックをDBに突っ込んで可視化するとこから始めます．  
ロガーといってますが，厳密にはロガー(DB)+ビジュアライザーですね．

### 要件定義
目的に従って少し話し合いを行いました
- 全てのトピックの周波数を知りたい
- 浮動点少数型配列を表示したい<-多次元のものはデータの検索が面倒なので無しになった
- 文字列型を表形式にしたい
- 時間範囲指定が過去の秒単位でしたい
- 部内のネットワークからのみ閲覧できれば良い

### 良い感じのプロジェクト発見
- [ros2_monitor_grafana](https://github.com/iwatake2222/ros2_monitor_grafana)  

InfluxDBに点を打って，Grafanaからクエリするってものです．  
InfluxDBとは時系列データベースというもので，高速性やデータ圧縮に優れています．  
{{<figure src="./20200819183059.png" alt="ハット基板" width="80%">}}  
([これ](https://www.mikan-tech.net/entry/what-is-influxdb)より引用)  
ちなみに，点を打つというのはsqlでいうレコードのことです．他にも，`bucket`はデータベース，`organization`はユーザのグループに近い概念です．  

Grafanaはデータの可視化・分析ができるwebアプリです．計算機のリソース使用状況などを表示したりするときに使っている人が多いイメージです．
詳しくは調べてください．  

もうこれでよいじゃん．って感じですが，データ(型の中身のこと)の保存とか部内での仕様を考える必要があります．

### docker-composeを書く
以下の通り．  
ホストOSでも後輩が動かしてたので大丈夫だと思います．
```yml
version: "2"
services:

  database:
    image: influxdb:2.4.0
    ports:
      - 8086:8086
    volumes:
      - ./influxdb/data:/var/lib/influxdb2
      - ./influxdb/config:/etc/influxdb2
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=my-user
      - DOCKER_INFLUXDB_INIT_PASSWORD=my-password
      - DOCKER_INFLUXDB_INIT_ORG=my-org
      - DOCKER_INFLUXDB_INIT_BUCKET=my-bucket
      - DOCKER_INFLUXDB_INIT_RETENTION=1w
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=my-super-secret-auth-token

  visualizer:
    image: grafana/grafana
    ports:
      - 3000:3000
    user: "472"
    volumes:
      - ./grafana:/var/lib/grafana
    depends_on:
      - database
```
それぞれデータやコンフィグをバインドマウントして配布性を上げています．

### 周波数を保存する
見つけたプロジェクトのものを使わせてもらいました．  
トピックのリストを抽出してDBクライアントに引き渡します．

### データを保存する
指定の型で出版されたトピックをそのまま入れてもよいのですが，制御用のトピックをそのまま使うのは勝手が悪いので  
`/log_hoge`から始まるトピックだけを保存するようにしました．配列型はタグを追加し，要素番号でフィルタ出来るようにしました．  
あとは，抽出されたトピックのリストからそれぞれ購読者を作ってデータをDBクライアントに引き渡します．

### テスト
てきとうな周波数で乱数を出版する浮動点少数配列型と，`Hello World:%d`などとインクリメントする文字列を作りました．  
先ほど作ったスクリプトを回して，DBクライアントを立ち上げます．  
データソースを追加して，Grafanaからクエリします．InfluxDB 2系ではFluxというクエリ言語を使います．
```sql
from(bucket: "hoge-bucket")
  |> range(start: 0, stop: 1d)
  |> filter(fn: (r) => r["_measurement"] == "ros2_topic")
  |> filter(fn: (r) => r["_field"] == "topic_rate_hz")
  |> filter(fn: (r) => r["topic_name"] == "/topic_1000_ms")
```
こんな感じに書いて，適当にOR文とかで抽出するものを変えます．[公式文書](https://docs.influxdata.com/flux/v0/)に詳しく書かれています(意外とこれしかない)．  

{{<figure src="./2023-12-22 022502.png" alt="ハット基板" width="100%">}}  
良い感じですね．ここではウィンドウ(一定間隔でのレコードのグループ)を五秒毎に設定していますが，後で後輩が一秒毎に使えるようにしてくれました．

### ダッシュボードを使う
今はGUIをポチポチしてダッシュボードを作ってますが，テンプレートとしてjsonを吐かして適応することが出来ます．  
個人的に考えているのは，用途別(足回り，アーム制御)などのダッシュボードと個人用のダッシュボードを作ってそれぞれのアカウントから見る仕様です．  
まあそこはユーザが良い案を考えてくれるでしょう!

### 設置する
現状の部のネットワークからこのように設置することにしました．  
省略しているところもありますが，なんとなくわかると思います．
{{<figure src="./drawio.png" alt="ハット基板" width="80%">}}  
ロガーのハードウェアはどんなものになるか分かりませんが，今のところタブレットパソコンを使うらしいので，制御用ルータと一緒に持ち運んで使えそうです．

### まとめ
さらっとですが，どんなものを作ったかぐらいは分かっていただけたと思います．  
実際，マルチプロセスでROSノードを動かしているだけなので，機能追加も楽だと思います．  
ここら辺はロボット制御者がやるには少し荷が重いですが，有ると無いとではデバッグ速度が段違いなので，更新していってほしいですね．  
幣部の制御班には画像認識などを行うカメラ班がありますが，こんな感じの基盤を管理する"インフラ班"なるものがあっても良いかもって思いました．
