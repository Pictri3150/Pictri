import SwiftUI

// MARK: - Color Journey Prototype Store
//
// "地図から場所を選ぶ→現地で写真を残す→場所と地図が色づく"という1本のフローを、
// 単一の状態源(step)から導出するための小さな状態管理。各画面が個別のBoolを
// 大量に持つ構造を避け、遷移はすべてここのメソッド経由でしか起こらないようにする。
//
// @Observableを採用する。このプロジェクトのdeployment target(IPHONEOS_DEPLOYMENT_TARGET
// = 26.4、project.pbxprojで確認済み)はObservation frameworkの要件(iOS 17)を
// 大きく上回っており、利用可能と確認した上で選んでいる
// (@StateObject/ObservableObjectより宣言が薄く、このプロトタイプの規模に合う)。
//
// すべての遷移メソッドはguardで「今の状態から呼んでよい遷移か」を確認してから
// 状態を進める。これにより、タップ連打で同じ遷移が二重発火しても
// (2回目のguardが失敗して)無害に無視される。

@Observable
final class ColorJourneyPrototypeStore {

    /// String準拠は起動引数(-pictriPrototypeStep)からの安全なパース用途のみ。
    /// フロー内部のロジックはこの生値を一切参照しない。
    enum Step: String, Equatable {
        case mapUnvisited
        case mapSelected
        case spotUnvisited
        case captureReady
        case capturing
        case captureCompleted
        case spotVisited
        case mapVisited
        case homeUpdated
    }

    enum TopDestination {
        case map
        case home
    }

    private(set) var step: Step
    private(set) var topDestination: TopDestination = .map

    /// 撮影完了直後だけtrueになる一時フラグ。SpotDetail側はこれを見て
    /// 「色づいた直後の軽い強調」を一度だけ行い、常時点滅はしない。
    /// clearJustColored()を呼ぶまで(=ColorJourneyFlowViewのtask内で短時間後に)trueのまま。
    private(set) var justColored = false

    /// DEBUG限定のQA用。特定のstepへ直接シークして起動された場合にtrueになり、
    /// ColorJourneyFlowView側の自動遷移(task内のTask.sleep)を止める。
    /// これにより、本来は一瞬しか表示されない中間状態(mapSelected/capturing/
    /// captureCompleted等)もスクリーンショットのために静止させて確認できる。
    /// 通常のインタラクティブ操作(初期値nilでの起動)には一切影響しない。
    let isDebugFrozen: Bool

    init(debugInitialStep: Step? = nil) {
        let resolvedStep = debugInitialStep ?? .mapUnvisited
        self.step = resolvedStep
        self.isDebugFrozen = debugInitialStep != nil
        self.justColored = resolvedStep == .captureCompleted
        self.topDestination = resolvedStep == .homeUpdated ? .home : .map
    }

    var isKanagawaVisited: Bool {
        switch step {
        case .spotVisited, .mapVisited, .homeUpdated:
            return true
        default:
            return false
        }
    }

    /// SpotDetail(未訪問〜訪問後、撮影シミュレーション表示中も含む)を表示すべきか。
    /// 撮影シミュレーションはSpotDetailの上にfullScreenCoverとして重ねるだけなので、
    /// 背後のSpotDetailは撮影中もずっと存在し続ける想定にする。
    var isShowingSpotDetail: Bool {
        switch step {
        case .spotUnvisited, .captureReady, .capturing, .captureCompleted, .spotVisited:
            return true
        case .mapUnvisited, .mapSelected, .mapVisited, .homeUpdated:
            return false
        }
    }

    var isCaptureSimulationPresented: Bool {
        switch step {
        case .captureReady, .capturing, .captureCompleted:
            return true
        default:
            return false
        }
    }

    // MARK: - Transitions

    /// 1つのタップで「選択の一瞬」を作り、ColorJourneyFlowView側のtask(id:)が
    /// 短い間を置いてconfirmKanagawaSelection()へ自動で進める
    /// (2段階タップを要求しない。要件の「タップ→拡大しながら遷移」を1操作で実現するため)。
    func tapKanagawa() {
        guard step == .mapUnvisited else { return }
        step = .mapSelected
    }

    func confirmKanagawaSelection() {
        guard step == .mapSelected else { return }
        step = .spotUnvisited
    }

    func beginCapture() {
        guard step == .spotUnvisited else { return }
        step = .captureReady
    }

    func shutter() {
        guard step == .captureReady else { return }
        step = .capturing
    }

    func finishCapturing() {
        guard step == .capturing else { return }
        justColored = true
        step = .captureCompleted
    }

    func revealSpotVisited() {
        guard step == .captureCompleted else { return }
        step = .spotVisited
    }

    func clearJustColored() {
        justColored = false
    }

    /// 撮影シミュレーションを撮影完了前に閉じた場合のキャンセル導線。
    /// captureCompleted以降(すでに色づいた後)は閉じても巻き戻さない。
    func closeCaptureSimulation() {
        guard isCaptureSimulationPresented, step != .captureCompleted else { return }
        step = .spotUnvisited
    }

    /// SpotDetail(未訪問/訪問後どちらからでも)からMapへ戻る。
    func returnToMap() {
        guard step == .spotUnvisited || step == .spotVisited else { return }
        step = isKanagawaVisited ? .mapVisited : .mapUnvisited
        topDestination = .map
    }

    /// Map⇄Homeの切り替え。SpotDetail/撮影中は対象外(呼び出し側がボタンを出さない)。
    func showHome() {
        topDestination = .home
        if isKanagawaVisited { step = .homeUpdated }
    }

    func showMap() {
        topDestination = .map
        if isKanagawaVisited { step = .mapVisited }
    }
}
