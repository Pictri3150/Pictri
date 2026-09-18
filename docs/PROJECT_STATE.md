# PROJECT_STATE.md — ピクトリ（Pictri）現在の実装状況

最終更新: 2026-08-24（PicTri Opening Signature Focus Handoff 完了、内部自己評価89/100）

## 2026-08-24 追記: Opening Signature Focus Handoff

前ラウンド(No Peel Signature Final、内部自己評価88/100)のFocus
Transferを10倍slow-motionで実機監査した結果、「PicTriが完全にsharpな
まま長時間保持され、Homeだけが先に大きくblur解除され、PicTriは最後に
ほぼ一括で消える」という非対称な体感になっていたと判明した
(`/tmp/pictri_opening_focus_signature/baseline_audit.md`)。PicTri側と
Home側が実質同じcurveをほぼ同時に共有していたのが原因。

「PicTriが先に手放し始め、Homeが追いかけて合焦し、両者が同じ終着点で
完了する」choreographyへ再設計(`pictriHandoffPicTriT`/
`pictriHandoffHomeT`、130ms差のlead/follow構造)。PicTri側のopacityは
3乗カーブで終盤にだけ効く「最後の整理」とし、blur/contrastを本体に
据えることで「opacity fadeで消えた」という印象を避けた。10x
slow-motionで実際にcrossoverの瞬間(PicTriが視認できるほどsoft化する
一方でHomeが明確にsharpになっていく瞬間)を確認済み。

PRECISION RACK FOCUS(blurのみ)/ LATENT FOCUS HANDOFF(contrast/
saturationも動く)/ DEPTH BREATH HANDOFF(微小scaleを追加)の3
choreographyを比較し、Clarity・Simplicity・Focus Physicalityの基準を
唯一満たしたRACK FOCUSを採用。

実装中、「2つのグローバル関数参照を三項演算子で選択する」書き方で
Swiftコンパイラが内部エラーを出す既知の問題(前ラウンドで発見済み)を
再度回避するため、closureで明示的にラップする書き方を踏襲した。

QA: iPhone 17 Pro Dark/Light、iPhone SE Dark、Reduce Motion、default
cold launch、5回連続daily-use評価。Performance実測(`ps`直接
サンプリング): CPU 3.9-8.5%、メモリ約213.5MB(前ラウンドから回帰なし)。
`xcodebuild clean build`: BUILD SUCCEEDED、error 0、new warning 0
(既存warning 3件のみ)。Home/Map/Camera/Vlog/Memoriesはコード無変更。
詳細・比較画像: `/tmp/pictri_opening_focus_signature/`。

**内部自己評価89/100**。最低点はOriginality(8/10)。派手なEffectを
足さずにstaggered choreography自体で差別化しているが、これ以上の
パラメータ調整だけで大きく伸ばすのは難しいと判断し、正直に報告した。

## 2026-08-24 追記: Opening No Peel Signature Final

ユーザーの最終判断により、Production OpeningからPeel(めくれ)表現を
完全撤去した。88点まで技術的に磨いたPeelだったが、実際に見た結果
「捲れる時間が短く、何が起きているのか分からない」という根本的な
問題が解消しきれなかったため、Peelという表現方式そのものを
Productionから外す決定がなされた。

新しい核: 暗闇 → PicTriがじわんと浮かび上がる → sharp → 静止 →
写真のピントが移るように世界のfocus/exposure/depthが変化 → 実Homeが
自然に現れる → PicTriはHomeへ溶ける。

CONCEPT A(FOCUS TRANSFER: blur中心)/ B(LATENT DEVELOPMENT: contrast/
saturation中心)/ C(OPTICAL DEPTH OPEN: scale中心)の3案を実機比較し、
Clarity・Simplicityを最重要視してCONCEPT Aを採用。Home(実
`ContentView()`)へは`JapanQuestApp.swift`の`PictriNoPeelRoot`が
Openingと同じ時間軸でblur/brightness/saturation/scaleを適用する
(HomeView/ContentView自体のコードは無変更、呼び出しサイトへ
modifierを重ねるだけ)。wordmarkはHomeの合焦開始より0.18秒遅れて
溶けるよう調整し(iteration 2)、「Homeが先にsharpになり始める→PicTri
が道を譲るように消える」という理解しやすい順序を作った。

Timing: dark 0.45 / emergence 0.85 / sharp lock 0.20 / stillness 0.40 /
Home optical reveal 1.30 / settle 0.30、合計3.50秒。

Reduce Motion再検証で、Home側のoptical stateとOpening完了タイミングが
ズレる新規不具合を発見・修正(Reduce Motion用の短いtimelineに揃えた
専用関数`pictriNoPeelHomeState_FocusReduced`を追加)。また実装中、
「2つのグローバル関数参照を三項演算子で選択してfunction-typedの
プロパティへ渡す」書き方でSwiftコンパイラが内部エラーを出す問題に
遭遇し、各関数参照を明示的なクロージャでラップして解消した。

Peel関連の実装(`PictriOpeningPeelLab.swift`,
`PictriOpeningCoreAnimationCurl.swift`)はDEBUG比較Lab
(`-pictriOpeningConcept final100` / `route-b`)としてそのまま残し、
Production経路(`PictriOpeningView`→`PictriRootWithOpening`)からは
完全に参照を外した。Cold LaunchでPeel関連のView/StripLayerが一切
生成されない。Performance実測(`ps`による直接サンプリング): CPU
4-10%(旧Peel版は瞬間29.5%まで到達)、メモリ約214.8MB。Peel撤去により
明確に軽量化された。

QA: iPhone 17 Pro Dark/Light、iPhone SE Dark/Light、Reduce Motion、
default cold launch(debug引数なし)、5回連続daily-use評価。
`xcodebuild clean build`: BUILD SUCCEEDED、error 0、new warning 0
(既存warning 3件のみ)。Home/Map/Camera/Vlog/Memoriesはコード無変更。
詳細・比較画像: `/tmp/pictri_opening_no_peel/`。

## 2026-08-24 追記: Opening Physical Peel Closure

前ラウンド(FINAL 100/100 Physical Peel Gate)で残っていた「wordmarkが
foldを通過する瞬間のごく短時間のせん断artifact」を根本修正した。

高密度slow-motion QA(revealDurationを一時的に10倍へ、検証後ただちに
本番値へ復元)でwordmark通過の瞬間を200-500%ズームし、"c"や"T"の
輪郭が「くの字」に折れて見えるartifactを再現・特定した。原因は
strip境界をまたぐ文字ストロークが、境界の左右で異なる`rotation3D`
角度を受けてしまうという、離散facetで連続曲面を近似する手法全般に
共通する幾何学的な限界(strip数やoverlapの調整だけでは解消不可)。

対策として背景とwordmarkを完全に分離した: 背景(平面color、細部を
持たないためfacet境界が知覚されない)はmulti-strip continuous curl
のまま、wordmarkは別レイヤーとして、foldが到達するまでは無変形、
foldが通過する短い間だけ「ただ1つの剛体」として単一角度で回転+mask
する構造(`pictriWordmarkRigidCrossing`)へ変更。strip境界をまたがない
ためせん断が構造的に発生し得ない。10x slow-motionでの複数回・複数
時点での再検証でartifact消失を確認。Reduce Motion版も同じ構造へ
統一(旧実装のまま残っていた場合、同種のartifactが理論上起こり得た
ため)。

比較のためCore Animation(CALayer + CATransform3D)によるRoute B
Prototypeも実装・実機テストした(`PictriOpeningCoreAnimationCurl.swift`、
DEBUG比較専用、Production非接続)が、strip描画が細い線にしかならない
未解決の実装課題と、Home露出maskの未実装により、Route A(SwiftUI)に
明確に劣ると判断(スコア89 vs 37、詳細は
`/tmp/pictri_opening_physical_closure/engine_comparison.md`)。
Metalは「両案が9/10に届かない場合のみ」という規定に従い不要と判断し
未導入。

Performance実測: `ps`によるCPU/メモリサンプリング(0.15秒間隔)で、
Opening全体を通じCPU 3-15%、peelの最も複雑なフレームで瞬間29.5%、
メモリは216MB前後で変動なし(リーク兆候なし)。xctrace「Animation
Hitches」「Activity Monitor」テンプレートはSimulatorで利用不可
だったため、CPU Profilerテンプレートおよび`ps`ベースの実測で代替。
5回連続cold launchで所要時間・見た目の一貫性を確認(daily-use評価)。

QA: iPhone 17 Pro Dark/Light、iPhone SE Dark/Light、Reduce Motion
(実機切替で確認)。`xcodebuild clean build`: BUILD SUCCEEDED、error 0、
new warning 0(既存warning 3件のみ、Route B実装で1件新規警告が
出たため`UIScreen.main`→`traitCollection.displayScale`へ修正して解消)。
Home/Map/Camera/Vlog/Memoriesはコード無変更。詳細・比較画像:
`/tmp/pictri_opening_physical_closure/`。

**内部自己評価94/100**。GATE01-21のうち文字通りの基準はすべて満たすが、
①Route B/Metalの完成度が比較のみに留まる(採用せず) ②Performance
実測はxctrace標準テンプレートではなく代替手段による ③GUIタップ注入
によるMap/Camera/Vlog/Memories遷移の自動テストは未実施(コード
無変更の確認に留まる)、の3点を理由に、100点ではなく94点と正直に
報告している。

## 2026-08-24 追記: Opening FINAL 100/100 Physical Peel Gate

前ラウンド(Pure Peel Refinement)をユーザー・第三者がフレーム単位で
再確認し、4点の未完成部分を指摘: ①wordmark背後の黄土色矩形Glow
②Peelが太い斜めband/wipeに見える ③Peelが短すぎる ④Opening中も
Status Barが表示され没入感を壊す。加えて既存の二重wordmark問題も
fadeでの緩和に留まっていた。今回すべて根本修正した。

①: `RadialGradient`を`.frame(234,180)`でクリップしていたのが原因と
特定。frameを撤廃し画面全体スケールの緩いfalloffのみに変更、矩形境界を
完全除去。②③: curlを1枚の矩形bandのrotation3Dから、7枚の薄いstripを
0°→80°まで滑らかにランプさせる構造(`pictriContinuousCurlWrapper`)へ
全面刷新。実装過程で2つの新規不具合を実機発見・修正: (a)strip数を
16まで増やすと文字が視覚的に断片化する(fragment化)不具合 → 90°を
超える「裏返し」表示を廃し`colorMultiply`による連続明暗のみに変更、
strip数を7・overlap9ptへ調整して解消。(b)strip opacityを下げると
下の平面contentとghost(二重表示)する不具合 → opacity減衰を廃し
不透明のままcolorMultiplyのみで暗くする方式に変更して解消。
revealDurationも0.90秒→1.40秒に延長、easingも中盤が急すぎた
crackPropagationから、なだらかなsmootherstepベースの
`pictriFinalPeelEasing`へ変更。④: `PictriRootWithOpening`側で
`isOpeningActive`に直接bindingした`.statusBarHidden`を追加。
Opening subview自身に付けると完了後もStatus Barが復帰しない不具合を
実機で発見し、常に存在するroot ZStack側へ付け替えて解消した。

Timing T2(dark 0.40 / emergence 0.85 / lock+stillness 0.65 / peel 1.40 /
settle 0.25、合計3.55秒)を採用。Peelの軸・向き(対角線約135°、右下角
起点)、S-curve silhouette、backface色はこれまでの実機検証結果を維持。

QA: iPhone 17 Pro Dark/Light、iPhone SE、Reduce Motion(`defaults write
com.apple.Accessibility ReduceMotionEnabled`で実機切替を確認 — 単純
fadeではなくwordmark emergence+小さなedge lift+短いmatte revealの
ブランドidentityを保った簡略版が正しく動作)、default cold launchを
確認。動画記録はこのマシンで`SimRenderServer`エラーにより引き続き
利用不可(CoreSimulatorService再起動を含め対策を試みたが解消せず)。
スクリーンショット連番、および一時的にrevealDurationを7倍に伸ばした
確認専用slow-motionビルド(検証後ただちに本番値へ復元)で
wordmark crossing部分を含めて検証した。
`xcodebuild clean build`: BUILD SUCCEEDED、error 0、new warning 0
(既存warning 3件のみ)。Home/Map/Camera/Vlog/Memoriesはコード無変更。
本番委譲先を`PictriOpeningView.swift`で`PictriPeelConceptFinal100`
へ切替済み。詳細・比較画像・README: `/tmp/pictri_opening_100_final/`。

**内部自己評価92/100。まだ100点でない理由(正直に記録)**:
wordmark crossing部分に、ごく短時間(1フレーム相当)だけ文字の縁に
わずかな粒立ちが見える瞬間がある(ghost/二重表示ではなくなったが
完全にゼロではない)。Metal / Core Animationでの再実装は行っていない
(改良版SwiftUI multi-strip法が実機評価で十分な水準に達したため、
追加のリスクを取らない判断)。

## 2026-08-24 追記: Opening Pure Peel Refinement

前ラウンド(Image-First Reference Match)はめくる方向・向きは正しいと
評価された一方、「何かいらないものが写っている」「普通に捲れるだけでいい」
という所感があった。構造分解監査(`/tmp/pictri_opening_pure_peel/audit.md`)
の結論: 実際に捲れているcurl band(wavy、局所的な形状)とは別に、画面全体を
横切る独立した直線のhighlight帯とcontact shadow帯が存在し、curlの形状と
連動していなかったため「面と無関係な光と影の筋」に見えていた。

これを削り、残すhighlight(rim light)とcontact shadowは必ずcurl band自身と
同じwavy silhouette(同じamplitude/reach)から導出するよう再設計
(`pictriPurePeelWrapper`)。Minimal(装飾ゼロ)/ Editorial(rim light・
contact shadowを控えめに)/ Cinematic(同じ装飾を強めに)の3案を実機
スクリーンショットで比較し(`/tmp/pictri_opening_pure_peel/concepts.md`)、
「存在を感じるが主張しすぎない」という要求に最も合致するEditorialを採用。
Wordmarkも46pt→41pt(約11%減)に縮小し、referenceの負のスペース比に近づけた。
Peelの軸・向き(対角線約135°、右下角起点)・S-curve silhouette・backface色
(Paper Edge)は前ラウンドのまま維持(正しいと評価された部分は変更せず)。

QA: iPhone 17 Pro Dark/Light、iPhone SE、default cold launch(debug引数
なし)で実Home露出・white flashなし・独立した直線ノイズが消えたことを
実機スクリーンショットで確認。Background→Foreground非復帰は
`PictriRootWithOpening`(`@State`がWindowGroupのscene生成時にのみ初期化
される既存アーキテクチャ、本ラウンドで無変更)により構造的に保証済み。
Reduce Motionフォールバックは前ラウンドまでに検証済みのコードを無変更で
流用(本ラウンドでは未再検証)。
`xcodebuild clean build`: BUILD SUCCEEDED、error 0、new warning 0
(既存warning 3件のみ)。Home/Map/Camera/Vlog/Memoriesはコード無変更。
本番委譲先を`PictriOpeningView.swift`で`PictriPurePeelConcept_Editorial`
へ切替済み。詳細・比較画像: `/tmp/pictri_opening_pure_peel/`。

**未解決の既知の差分(正直に記録)**: rim light/contact shadowの強度は
数値パラメータによる近似であり、物理シミュレーションではない。動画記録は
このマシンでは`SimRenderServer`エラーにより引き続き利用不可、スクリーン
ショット連番で代替(前ラウンドから継続する既知のツール制限)。

## 2026-08-24 追記: Opening Image-First Reference Match

前ラウンド(Cinematic Peel Finalization、内部自己評価84/100)をユーザーが
Visual Review(見た目)の観点で不採用と判断。今回はユーザー提供の実画像
(6-panelストーリーボード、ローカル design mockup `pictriimageopening.png`)
を唯一のVisual Source of Truthとし、**前ラウンドの実装を保護対象とせず**、
画像の実測値からOpeningを作り直した(過去ラウンドの数値・パラメータは
一切引き継いでいない)。

Phase 0(Reference Forensics)としてPython/PIL/numpyで6パネルを切り出し、
wordmarkの位置・サイズ比、peel front lineの角度(実測 約135°の対角線、
水平ではない)、色5点(Deep Graphite `#08080D` / Charcoal `#141416` /
Soft Gold `#D6C79A` / Paper Edge `#2A2A2D` / Glass Accent `#1A1A1C`)を
数値・hexで記録(`/tmp/pictri_opening_reference_match/REFERENCE_GEOMETRY.md`
ほか)。前ラウンド実装とのMismatch Auditを作成し、「wordmark色」と
「peel軸/silhouette」が完全に別物であることを正直に記録した上で全面再構築。

変更点: ①Wordmarkを冷たいivoryから温かいengraved gold(`#D6C79A`)へ、
3層stackで簡易embossを再現。②Peelを水平・下端起点から対角線(約135°)・
右下角起点へ全面変更。実装初期(v1)で「起動直後から右下角が既に露出している」
signed-distance計算の不具合を発見・修正(v2で解消)。③Curl silhouetteに
Referenceが見せるorganic S-curveを近似するsin波(前線からの符号付き距離に
対する反対称な単一hump、peel進行に応じて振幅増加)を追加、直線的すぎた
v1〜v2から差し替え(v3)。④Backfaceを実測Paper Edge(`#2A2A2D`)に統一。
Wordmarkは面に「印字」されており、剥がれる面と共に傾いて退出する(fadeで
消えない)ことを実機スクリーンショットで確認。

Peel技術はSwiftUIのdiagonal masking + `rotation3DEffect`のみを採用
(Core Animation / Metal mesh変形は今回プロトタイプせず — 既にreference方向に
十分近づいており、追加のリスクに見合わないと判断。正直に未実施と記録)。
Reduce Motionフォールバックは前ラウンドまでに検証済みのコードを無変更で流用。

QA: iPhone 17 Pro Dark/Light、iPhone SE(画面サイズ違いでも幾何が破綻しない
ことを確認)、本番想定のdefault cold launch(debug引数なし)でReal Home
(実ContentView())への遷移を確認。**このマシンでは`xcrun simctl io
recordVideo`がセッション全体で`SimRenderServer`エラーにより失敗**(screenshot
自体は正常動作、コード変更とは無関係なツール側の問題)。動画の代わりに
タイムスタンプ付きスクリーンショット連番で記録(`/tmp/pictri_opening_reference_match/
audit/v3/`, `user_review/implementation_frames/`)。
`xcodebuild clean build`: BUILD SUCCEEDED、error 0、new warning 0
(既存warning 4件のみ)。Home/Map/Camera/Vlog/Memoriesはコード無変更。
本番委譲先を`PictriOpeningView.swift`で`PictriPeelConceptReferenceMatch`
へ切替済み。詳細・比較画像・README: `/tmp/pictri_opening_reference_match/`。

**未解決の既知の差分(正直に記録)**: curl silhouetteのS-curveは単一sin波の
近似であり、referenceが示唆する連続的な物理変形そのものではない。Peel技術は
1方式(SwiftUI)のみ検証、Method B(Core Animation)/C(Metal)は未着手。

## 2026-08-23 追記: Opening Cinematic Peel Finalization

前ラウンド(Peel Reveal Rebuild、内部自己評価81/100)の弱点(A: curlの
立体感が弱い B: maskで消えているように見える危険 C: 状態変化が静かすぎる
D: PicTri文字の出現が断片組み立てに見える複雑さ)を再定義し、Typography と
Peel の2点だけを磨き直した。Typographyはfragment/tileを廃し、単一Textの
contrast/blurのみで潜像が現像するように定着する「Latent Image」へ変更。
Pealは「Segmented 3D Curl」を新設計 — **開発中、5分割で試作した際に
回転角90°付近でのforeshorteningにより帯状の継ぎ目(seam)が実機相当の
録画で発覚し、2分割・安全角度域(最大約82°)へ設計を修正して解消した**。
curvature連動highlight・持ち上がるほど強まるcontact shadow・先端側の
backface tint(cool-neutral gray)を追加。静止終盤にSurface Tensionの
ごく短いpulseを追加しDynamic Qualityを補強。内部自己評価84/100(90点gate
未到達、正直に報告)。詳細: `/tmp/pictri_opening_peel_final/`。
17 Pro/SE/Dark/Light/Reduce Motion/Cold Launch/background非復帰を確認。
`xcodebuild clean build`: BUILD SUCCEEDED、error 0、new warning 0
(既存warning 4件のみ)。Home/Map/Camera/Vlog/Memoriesはコード無変更。

## 2026-08-23 追記: Opening Peel Reveal Rebuild

Openingの中核メカニクスを「crack(亀裂)」から「peel(めくれ/剥離)」へ転換。
5段階(Foundation → Typography Emergence → Peel/Reveal Mechanics →
Cinematic Polish → Final Reality Check)で構築(詳細: `/tmp/pictri_opening_peel/
PROGRESS.md`)。Typography Emergenceは3案(Latent Fragments断片収束 /
Exposure Bloom光陰影のみ / Block Assembly大版)を比較しLatent Fragmentsを採用
(Photography DNA最強)。Reveal Mechanicsは3案(Peel / Seam継ぎ目開き /
Latent Split中央開口)を比較し、Seamはwordmark自体が二重化して破断する
致命的欠陥、Latent Splitは実装した幾何が意図と逆転する不具合を発見、
いずれも不採用としPeelを採用。画面下端から上端へ1枚の面がめくれ(front付近の
帯だけを3D回転させ巻き上がる質感+影を添える)、既に背後に実描画されている
Homeへ直接変形する(二段fadeなし)。起動尺は内部タイムラインで約3.3秒
(要求レンジ3.0〜4.5秒に適合)。同フェーズで起動直後の白いNative Launch
Screen(約2秒)も、`PictriLaunchBackground`色を`UILaunchScreen`へ指定する形で
解消済み(Openingのgraphite-blackと完全一致)。実装は`PictriOpeningPeelLab.swift`
の`PictriPeelConceptFinal`、本番委譲は`PictriOpeningView.swift`。
17 Pro/SE/Dark/Light/Reduce Motion/Cold Launch/background非復帰を確認。
`xcodebuild clean build`: BUILD SUCCEEDED、error 0、new warning 0
(既存warning 4件のみ)。Home/Map/Camera/Vlog/Memoriesはコード無変更。

## 2026-08-23 追記: Opening Cinema Phase

前回v4(Iris Glimpse → Lens Focus Pull)は「2つの異なる視覚文法を中間で接着した」
ことがシンプルさ・映画的没入感の不足の原因と再監査で判明。単一の強い写真的
モチーフを最後まで貫く4案(Rack Focus / Exposure Print / Aperture Breath /
Afterimage)をゼロから構築・録画・10基準で厳格採点し、**Exposure Print(v5、
81/100)**を採用。暗室で印画紙が現像される過程(film grain→非線形contrast上昇→
定着)をモチーフにした。前回の技術的事故(`.brightness()`全体適用による灰色洗い)は
pulseをwordmark単体に限定する設計で構造的に回避。消え際にwordmarkがgrainより
一瞬早くフェードする「余韻」も追加。詳細: `/tmp/pictri_opening_cinema_v2/`
(audit.md / concepts.md / scoring.md)。Home/Map/Camera等の他画面・Core Invariantsは
無変更。`xcodebuild clean build`: BUILD SUCCEEDED、error 0、new warning 0。

## 2026-08-22 追記: Secondary Experience Finalization Phase

SpotDetail(`QuestSpotDetailView`, MapView.swift)・Profile(`JQAccountSheetView`,
HomeView.swift)・FriendProfile(`FriendProfileSheet`, HomeView.swift)の3画面を
Matte Photographic Editorial Design(PictriFinalTheme/PictriDarkTheme)へ統一。

- **SpotDetail**: それまで`.white`/`.black`ハードコード+旧`PictriTheme`のままで
  Appearanceに一切追従していなかったのを全面刷新。lock badge・スタンプラリー的な
  capsule群・「景色→表情」ステップ予告を廃止し、識別(県shape glyph+タイポグラフィ)→
  静かな状態文(「まだ残していない場所」/「ここで残せます」/「ここでの記憶がある」)→
  単一CTA(Anywhere Captureのため常に有効)→実Memory写真、という構成に整理。
- **Profile**: 3-stat-card row(友達/訪れた県/スポット)とSettings dashboard的な
  4-tab構成を廃止。header直下に実写真の「最近の記憶」ストリップを追加し主役にした。
  友達/追加/申請/設定の4tabは残しつつ既定を「友達」寄りへ、設定は最後尾へ後退。
- **FriendProfile**: 既に近い構造だったため軽微な調整(統計カードのchromeを除去、
  閉じるボタンをglass化、写真タイルにhairline枠を追加)。
- Cross-screen regression実施、Home/Map/Camera/Vlog/Memories/FREE-Premium gate/
  Memory Flipに影響なし。`xcodebuild clean build`: BUILD SUCCEEDED、error 0、
  new warning 0。

## 2026-08-22 追記: Visual Reality Check Phase

前回セッションの「実装報告上A」を鵜呑みにせず、実スクリーンショット・ピクセル計測・
実写真データ(DEBUG seed)で再検証し、見つかった問題をその場で修正した。

**発見・修正した実バグ:**
- Map: Light modeで未訪問県がほぼ完全に背景へ沈んでいた(token流用が原因) → Map専用
  token(`mapUnvisitedFill`/`mapUnvisitedStroke`)を新設し解消。
- Map: `PictriJapanCollectionMapPalette.light`が`static let`だったため、Appearanceを
  Live切替してもMapの配色だけ起動時のmodeに固定されたままになるバグを発見・修正
  (`static var`化)。あわせて未接続のまま残っていたbrown-cast色の`.dark`固定パレット
  (死にコード)を削除。
- Map: 「家族や友だちにシェアしよう」カード(AI-template的な構造、Mapの役割に無関係)を削除。
- Opening: `.brightness()`のpulse値が大きすぎ、静止フレームで画面全体が灰色に
  洗い流される不具合を発見・修正。
- Home: Memory Flip(実写真データで再検証)は正しく動作するが、静止状態が通常の
  単一写真カードと視覚的に区別できない問題を発見。「Dual Memory Stack」
  (裏面写真をごく少し覗かせるpeek layer)を新Home Concept Labで検証・採用。
  比較対象の他2案(Editorial Spread / Memory Reveal)は実装時に固有のバグが見つかり
  (前者はレイアウト崩れ、後者はcomposite画像により演出が機能しない)不採用。

**Opening: v3(Lens Focus Pull単体)からv4(Iris Glimpse → Lens Focus Pull)へ差し替え。**
前回セッションで「geometry bugのため不採用」としていたAperture Irisを、
三角形+`.clipShape(Circle())`の単純な構成に書き直して修復。Lens単体・Iris単体・
Hybridの3本を録画・10基準で採点し、Hybrid(82/100)を採用(詳細:
`/tmp/pictri_visual_reality_check/opening/scoring_final.md`)。

**Git:** 引き続き未コミット。

> **プロダクト名:** PicTri — *picture trip* に由来
> **内部プロジェクト名:** JapanQuest（Xcode・Bundle ID・型名はそのまま）

---

## 2026-08-22 夜間セッション: Visual Direction Consolidation + Experience Redesign

以下より下のセクション(ビルド状態〜既知の課題)は2026-06-07時点のスナップショットで、
現在のファイル構成・画面構成とは大きく乖離している(Home/Map/Camera/Memoriesが
その後の複数セッションで大幅に作り直された)。正確な最新状態は本セクションを参照。

**今夜の変更点(概要):**
- Dark/Light 両対応のMatte Design System(`PictriDarkTheme`がmode-aware化、
  espresso/brownカラーキャストをcool-neutral graphiteへ刷新)
- `PictriAppearanceStore`によるAppearance設定(Account シート内、UserDefaults永続化)
- Bottom Navigationを5-tab化(Home/Map/Camera/Vlog/Memories)、Cameraを幾何学的に中央配置
- Memories内の重複していた日本地図(`PictriMemoriesJapanGlance`)を削除、Map側に一本化
- Home feedに`PictriMemoryFlipCard`(表=場所/裏=自分)を統合(自分の投稿のみ、
  dual capture素材がある場合)
- Opening(起動演出)をv3 "Lens Focus Pull"へ全面刷新。3案を録画・8基準でスコアリングし
  選定(詳細: `/tmp/pictri_opening_lab/scoring.md`、動画・フレームは同ディレクトリ)
- Camera の simulator placeholder(`demoCameraBackground`)に残っていたハードコード
  brown-cast RGBを、mode-aware neutralトークンへ修正
- `-pictriStartTab vlog`が機能していなかったバグを修正(`PictriVisualReview.startTab`に
  `.vlog`ケースが無かった)

**ビルド:** `xcodebuild clean build` → BUILD SUCCEEDED、error 0、warning 4
(すべて今夜以前からの既知警告: QuestAreaResolver 1件・QuestCameraPreview 2件の
非推奨API警告 + AppIntents metadata notice 1件。新規warning 0)

**Git:** 未コミット(ユーザー指示によりコミット・pushは行っていない)。
`git status --short` / `git diff --stat` は作業ツリーで確認可能。

**QA:** iPhone 17 Pro / iPhone SE の両方でDark・Light・5画面(Home/Map/Camera/
Memories/Vlog)を確認。FREE 0/3・3/3・Premiumの3状態、Anywhere Capture UIも
スクリーンショットで確認済み。Home上のMemory Flip統合は、既存の(Memories詳細で
実証済みの)コンポーネント・メソッドを再利用しているため構造的に健全と判断したが、
このsimulatorに実写真データが無く(モックfeedは全件`imageName: nil`)、実際にflipする
様子は今夜は視覚確認できていない(フォールバックで通常のPhotoPrint表示になることのみ確認)。

**既知の未着手/持ち越し:**
- Camera Aperture Iris(絞り羽根)Opening conceptは着想は強いが、羽根ジオメトリに
  実装バグがあり(`PictriOpeningLabConcepts.swift`の`bladeShape`)、今夜は不採用。
  修正すれば有力な次点候補。
- Home Memory Flip統合の実写真での目視確認(上記参照)。
- developerUnlockModeのデフォルト値は要再確認(App Store提出前に`false`必須、
  CLAUDE.md記載のルール)。

---

## ビルド状態

| 項目 | 状態 |
|-----|------|
| Xcode Build | **Succeeded** |
| ブランチ | `main` |
| 最新コミット | Polish memories explore detail sheet |
| 最新 Swift コード変更 | Polish memories explore detail sheet |
| ワーキングツリー | クリーン |

---

## コミット履歴（直近）

```
2441295  Polish memories explore detail sheet
d6c46f7  Update project state after home social feed polish
465efa8  Polish inline home social feed
1c1f552  Update project state after home social interactions
9d8c2ea  Add inline home social interactions
```

---

## 完了済みステップ（主要）

| ステップ | 内容 | コミット |
|---------|-----|---------|
| Step 1-A | レガシーファイル5本削除・死にコード除去 | Fix build error and complete Step 1-A cleanup |
| Step 1-B-1 | MemoriesView.swift 分割（452行） | Extract Memories views from ContentView |
| Step 1-B-2 | 旧 Account 系 死にコード削除（8型、429行削減） | Remove unused legacy account views |
| Step 1-B-3 | CameraView.swift 分割（1043行） | `4d6e29b` |
| Step 1-B-4 | MapView.swift 分割（384行） | `fab79d6` |
| Step 1-B-5 | HomeView.swift 分割（975行、13型） | `74c68f6` |
| Step 2-A | developerUnlockMode デフォルト false 化 | `7232f65` |
| Step 3-A | Home Hero カードにスポット進捗を実データ反映 | Show spot progress in home hero card |
| Step 3-B | EmptyFeedCard を Map-first な空状態に改善 | Update empty home state for map-first journey |
| Step 3-E | コアフロー確認（コード上・破損なし）| コミットなし（実機確認は別途必要） |
| Step 3-F | Camera 保存フィードバック UI 改善 | `103f968` |
| Step 3-G | UI 表示名を「ピクトリ」に変更 | `ce2df41` |
| Step 3-H | Home Hero カード Map 導線改善 | `43e9fca` |
| Step 3-I | Home「気になるスポット」セクション追加 | `651d464` / `cc15bf9` |
| Camera 保存後改善 | 「Memoriesで確認する」CTA を primary スタイルに格上げ | `f591d33` |
| Step 3-D | QuestSpotDetailView の heroStatusChip を3-state 対応に | `31831c4` |
| Memories UI 改善 | サマリータイルで実写真表示・ヘッダー文言改善・mappin アイコン | `e09368a` |
| Memories Explore Stage 1 | コレクト/探索モード切り替え・横スクロールカルーセル・ExplorePhotoCard | `dbb2b0c` |
| Memories Explore Stage 2 | スナップスクロール・カード影・カルーセル垂直配置改善 | `6693d59` |
| Memories Explore 日付改善 | `ExplorePhotoCard` の日付を `"M月d日"` 形式に整形（`formattedDate`） | `730e530` |
| Memories Collect 達成感強化 | 県別サマリーカードに進捗バー・達成テキスト・コンプリート演出を追加（`completedCount / totalSpotCount` 活用） | `7b1e38b` |
| Memories Explore Stage 3 | Exploreカードをタップで `ExplorePhotoDetailSheet` 表示。写真全面 + スポット名・エリア名・日付。`ExploreCardButtonStyle` で押下フィードバック | `4d5b257` |
| QuestSpotDetailView ダークテーマ統一 | 白背景を廃止し黒基調に統一。statusCard / statusItem / actionButton / memoryPreview を暗背景向けに調整。セマンティックカラー4種追加 | `5a284a9` |
| Camera 文言修正・死にコード削除 | 「保存してシェア」→「メモリーに保存」。アイコン paperplane→bookmark。「Memoriesに/で」→「メモリーに/で」。未使用の `cameraBootView` 削除 | `b047f5e` |
| Home Social Layer Stage 1 | 投稿カード上でいいね（`likedPostIds`）・コメント（インライン入力）・プロフィールSheet（`FriendProfileSheet`）を実装。投稿詳細依存を排除。「保存した場所」セクション削除 | `9d8c2ea` / `2353c6e` |
| Home Social Layer Stage 2 | いいねを footer へ移動・like count 表示。`daysLeftText` 削除（消滅SNS感除去）。EmptyFeedCard コピー修正。FriendProfileSheet モック値削除・実データ表示。`JQAccountMenuRow` chevron 削除 | `465efa8` |
| Memories Explore Stage 4 | `ExplorePhotoDetailSheet` 品質強化。グラデーション stop 改善（上部 40% 透明維持）。キャプション fade-in。写真なし fallback に `mappin.and.ellipse` 追加。右上 close button 追加。キャプション間隔整理。「コレクトで見る」テキスト導線追加（viewMode binding 経由）。Store / Model 変更なし | `2441295` |

---

## 現在のファイル構成

| ファイル | 行数 | 状態・備考 |
|---------|-----|-----------|
| `ContentView.swift` | 186行 | Root / TabBar / JQUI / AppBackground のみ |
| `HomeView.swift` | ~908行 | Home 系 + JQAccount 系（Social Layer Stage 1 実装済み） |
| `MapView.swift` | ~417行 | QuestMapView / QuestSpotDetailView（heroStatusChip 追加済み・ダークテーマ統一済み） |
| `CameraView.swift` | 1043行 | QuestCameraView 系（4型） |
| `MemoriesView.swift` | ~750行 | MemoriesView 系 + ExplorePhotoCard + ExplorePhotoDetailSheet + MemoryVisualStyle（Explore Stage 1/2/3/4 + 日付改善 + Collect 達成感強化済み） |
| `QuestModels.swift` | 172行 | **要精査**（旧モデルが残存） |
| `QuestSampleData.swift` | 618行 | **要精査**（旧モックデータが残存） |
| `QuestMemoryStore.swift` | 267行 | 安定 |
| `QuestFriendStore.swift` | 54行 | 安定 |
| `QuestLocationManager.swift` | 90行 | 安定 |
| `QuestCameraService.swift` | 221行 | 安定 |
| `QuestCameraPreview.swift` | 46行 | 安定 |
| `QuestMapKitView.swift` | 411行 | 安定 |
| `QuestOverlayRenderer.swift` | 109行 | 安定 |
| `QuestProofBadge.swift` | 98行 | 安定 |
| `ShareSheet.swift` | 20行 | 安定 |
| `JapanQuestApp.swift` | 10行 | 完了 |

---

## 各画面の現状

### Home（動作確認未実施）
- 「ピクトリ」表示・Hero Map導線・スポット進捗・空状態 Map-first 文言 — 改善済み
- 「気になるスポット」セクションあり
- **Social Layer Stage 1 実装済み（`9d8c2ea` / `2353c6e`）:**
  - 投稿カード上でいいね（`likedPostIds`）・アニメーション付き
  - 投稿カード上でコメント入力・インライン表示
  - 投稿ヘッダーから `FriendProfileSheet`（軽量プロフィール表示）
  - `HomePostDetailSheet` 参照を完全排除
  - 「保存した場所」セクション削除
  - セクション名: 「フレンドの旅の記録」
- **Social Layer Stage 2 実装済み（`465efa8`）:**
  - いいねボタンを postHeader から postFooter へ移動（コメントと並列配置）
  - いいね数を表示（`baseLikeCount` + `isLiked` 差分でインライン計算）
  - `daysLeftText`（"あとN日" / "まもなく消えます"）を完全削除 → 消滅SNS感を除去
  - postHeader サブタイトルが `post.displayPlace` のみになり簡潔化
  - コメント表示を最大3件に制限（`.prefix(3)`）
  - EmptyFeedCard コピーを「フレンドが旅先で記録を残すと、ここに表示されます。」に修正
  - `FriendProfileSheet` の hashValue 偽値（`recordCount`/`spotCount`）を削除
  - FriendProfileSheet bio を「最近の記録: \(post.displayPlace)」（実データ）に変更
  - `JQAccountMenuRow` の `chevron.right` アイコンを削除（無反応UIシグナルを除去）

### Map（コアフロー実機確認済み）
- `QuestSpotDetailView` に `heroStatusChip` 追加済み（撮影済み / 撮影可能 / 未撮影 を3-state 表示）
- **`QuestSpotDetailView` ダークテーマ統一済み**（`5a284a9`）: 白背景を廃止し黒基調に。`statusCard` / `actionButton` / `memoryPreview` を暗背景向けに調整。Map → SpotDetail → Camera の世界観断絶を解消
- `developerUnlockMode = false`（現地認証が有効）
- 神奈川のみ表示

### Camera（動作確認未実施）
- 2枚連続撮影フロー（内カメ → 外カメ）
- `developerUnlockMode = false`（`#if DEBUG` トグルで開発時解除可）
- 保存後: 「メモリーに保存しました」+ primary CTA「メモリーで確認する」
- 保存ボタン: 「メモリーに保存」（bookmark.fill アイコン）— 旧「保存してシェア」(paperplane) から修正済み
- `cameraBootView`（未使用 24行）削除済み

### Memories（動作確認未実施）
- 県別サマリーカード + 詳細ビュー
- **サマリーカードのプレビュータイルで実際の写真サムネイルを表示**（`e09368a`）
- **ヘッダーサブテキスト: 「現地で撮った写真が記録になる」**（旅の記録寄りに改善）
- **未訪問・空セルのアイコンを `mappin` に変更**（フラグ感・ゲーム感を除去）
- **Exploreモード Stage 1 実装済み**（`dbb2b0c`）: コレクト/探索切り替え・横スクロールカルーセル・スケール演出
- **Exploreモード Stage 2 実装済み**（`6693d59`）: スナップスクロール（`.scrollTargetBehavior(.viewAligned)`）・カード影・カルーセル垂直配置改善
- **ExplorePhotoCard 日付表示改善済み**（`730e530`）: `createdAtText` を `"M月d日"` 形式に整形（`formattedDate` computed property）
- **Collectモード 達成感強化済み**（`7b1e38b`）: `PrefectureMemorySummaryCard` に進捗バー・「あと N スポット」/「コンプリート」テキストを追加。固定グリッド・未訪問プレースホルダー・gridIndex 思想は維持
- **Exploreモード Stage 3 実装済み**（`4d5b257`）: Exploreカードをタップ → `ExplorePhotoDetailSheet` がシート表示。写真全面・グラデーションオーバーレイ・スポット名/エリア名/日付。`ExploreCardButtonStyle` で押下フィードバック。Collectモード・Store・Model への変更なし
- **Exploreモード Stage 4 実装済み**（`2441295`）: `ExplorePhotoDetailSheet` 品質強化。グラデーションを stop 形式で改善（上部 40% 完全透明 → 写真が主役になる）。キャプション fade-in（`.onAppear` 0.28s）。写真なし fallback に `mappin.and.ellipse` アイコン追加（グラデーション背景 + アイコン = 記録カード感）。右上に控えめな close button 追加。「コレクトで見る」テキスト導線（`viewMode` binding で切替 + dismiss）。Collectモード・Store・Model 変更なし
- Stage 5（本格的な 2D 空間配置）は別ファイル分離を推奨、未実装

### Account（動作確認未実施）
- `JQAccountSheetView`（Home 右上アイコンからシート表示）
- フレンド管理（ローカルのみ、Firebase 未接続）

---

## コアフローの確認状況

| フロー | 状態 |
|-------|------|
| Home → Map タブ遷移 | **実機確認済み** |
| Map スポット選択 → SpotDetailView 遷移 | **実機確認済み** |
| SpotDetailView → Camera へ activeCameraSpotId を渡す | **実機確認済み** |
| Camera で2枚撮影 → QuestMemoryStore.save() | **実機確認済み** |
| 保存後 Memories に自動反映（Collect + Explore） | **実機確認済み** |
| Explore カードタップ → 詳細シート表示 | **実機確認済み** |
| Home 進捗（スポット数）反映 | **実機確認済み** |
| Home フィードにポストが表示 | 未確認 |
| Account シートの開閉 | 未確認 |

---

## 既知の課題

1. **カメラ権限なしのフォールバック未確認**（App Store 提出前に必須）
2. **旧モデル型が QuestModels.swift に残存**（`RecentQuestPost` 等5型 — Step 1-B-7 候補）
3. **Map は神奈川のみ**（他県スポットデータはあるが Map 画面は kanagawa フィルタのみ）
4. **Home フィード・Account シートの実機確認が未完了**（コアフロー本線は確認済み）
