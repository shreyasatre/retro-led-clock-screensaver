//  Retro LED Clock — a vintage 7‑segment clock screensaver for macOS 26+.
//  Single-file ScreenSaver module. Build with ./build.sh

import ScreenSaver
import AppKit
import QuartzCore

// MARK: - Themes

struct ClockTheme {
    let name: String
    let color: NSColor
}

let kThemes: [ClockTheme] = [
    ClockTheme(name: "Red",    color: NSColor(srgbRed: 1.00, green: 0.16, blue: 0.10, alpha: 1)),
    ClockTheme(name: "Blue",   color: NSColor(srgbRed: 0.22, green: 0.42, blue: 1.00, alpha: 1)),
    ClockTheme(name: "Yellow", color: NSColor(srgbRed: 1.00, green: 0.86, blue: 0.20, alpha: 1)),
    ClockTheme(name: "Green",  color: NSColor(srgbRed: 0.30, green: 1.00, blue: 0.38, alpha: 1)),
    ClockTheme(name: "Purple", color: NSColor(srgbRed: 0.68, green: 0.30, blue: 1.00, alpha: 1)),
    ClockTheme(name: "Orange", color: NSColor(srgbRed: 1.00, green: 0.50, blue: 0.10, alpha: 1)),
    ClockTheme(name: "Pink",   color: NSColor(srgbRed: 1.00, green: 0.32, blue: 0.62, alpha: 1)),
    ClockTheme(name: "White",  color: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.92, alpha: 1)),
]

// MARK: - Settings

final class ClockSettings {
    static let moduleName = "com.local.RetroLEDClock"
    private let d: UserDefaults

    init() {
        d = ScreenSaverDefaults(forModuleWithName: ClockSettings.moduleName) ?? UserDefaults.standard
        d.register(defaults: [
            "theme": 0,
            "use24h": false,
            "showSeconds": false,
            "showAMPM": true,
            "blinkColon": true,
            "burnIn": true,
            "size": 0.5,
            "brightness": 1.0,
            "showPanel": true,
        ])
    }

    var theme: Int {
        get { max(0, min(kThemes.count - 1, d.integer(forKey: "theme"))) }
        set { d.set(newValue, forKey: "theme") }
    }
    var use24h: Bool      { get { d.bool(forKey: "use24h") }      set { d.set(newValue, forKey: "use24h") } }
    var showSeconds: Bool { get { d.bool(forKey: "showSeconds") } set { d.set(newValue, forKey: "showSeconds") } }
    var showAMPM: Bool    { get { d.bool(forKey: "showAMPM") }    set { d.set(newValue, forKey: "showAMPM") } }
    var blinkColon: Bool  { get { d.bool(forKey: "blinkColon") }  set { d.set(newValue, forKey: "blinkColon") } }
    var burnIn: Bool      { get { d.bool(forKey: "burnIn") }      set { d.set(newValue, forKey: "burnIn") } }
    var size: Double      { get { d.double(forKey: "size") }      set { d.set(newValue, forKey: "size") } }
    var showPanel: Bool   { get { d.bool(forKey: "showPanel") }   set { d.set(newValue, forKey: "showPanel") } }
    var brightness: Double { get { d.double(forKey: "brightness") } set { d.set(newValue, forKey: "brightness") } }

    func save() { d.synchronize() }
}

// MARK: - 7-segment geometry

/// Segment indices: 0=a(top) 1=b(top-right) 2=c(bottom-right) 3=d(bottom) 4=e(bottom-left) 5=f(top-left) 6=g(middle)
private let kDigitSegments: [[Int]] = [
    [0, 1, 2, 3, 4, 5],     // 0
    [1, 2],                 // 1
    [0, 1, 6, 4, 3],        // 2
    [0, 1, 6, 2, 3],        // 3
    [5, 6, 1, 2],           // 4
    [0, 5, 6, 2, 3],        // 5
    [0, 5, 6, 4, 3, 2],     // 6
    [0, 1, 2],              // 7
    [0, 1, 2, 3, 4, 5, 6],  // 8
    [0, 1, 2, 3, 5, 6],     // 9
]

private func addHorizontal(_ p: CGMutablePath, y: CGFloat, x0: CGFloat, x1: CGFloat, t: CGFloat) {
    let h = t / 2
    p.addLines(between: [
        CGPoint(x: x0, y: y), CGPoint(x: x0 + h, y: y + h), CGPoint(x: x1 - h, y: y + h),
        CGPoint(x: x1, y: y), CGPoint(x: x1 - h, y: y - h), CGPoint(x: x0 + h, y: y - h),
    ])
    p.closeSubpath()
}

private func addVertical(_ p: CGMutablePath, x: CGFloat, y0: CGFloat, y1: CGFloat, t: CGFloat) {
    let h = t / 2
    p.addLines(between: [
        CGPoint(x: x, y: y0), CGPoint(x: x + h, y: y0 + h), CGPoint(x: x + h, y: y1 - h),
        CGPoint(x: x, y: y1), CGPoint(x: x - h, y: y1 - h), CGPoint(x: x - h, y: y0 + h),
    ])
    p.closeSubpath()
}

/// Adds one segment of a digit whose bottom-left corner is `o`, size w × h, stroke thickness t.
private func addSegment(_ seg: Int, to p: CGMutablePath, o: CGPoint, w: CGFloat, h: CGFloat, t: CGFloat) {
    let g = t * 0.14                       // small gap between segments
    let left = o.x + t / 2, right = o.x + w - t / 2
    let bottom = o.y + t / 2, mid = o.y + h / 2, top = o.y + h - t / 2
    switch seg {
    case 0: addHorizontal(p, y: top,    x0: left + g, x1: right - g, t: t)
    case 6: addHorizontal(p, y: mid,    x0: left + g, x1: right - g, t: t)
    case 3: addHorizontal(p, y: bottom, x0: left + g, x1: right - g, t: t)
    case 5: addVertical(p, x: left,  y0: mid + g,    y1: top - g, t: t)
    case 1: addVertical(p, x: right, y0: mid + g,    y1: top - g, t: t)
    case 4: addVertical(p, x: left,  y0: bottom + g, y1: mid - g, t: t)
    case 2: addVertical(p, x: right, y0: bottom + g, y1: mid - g, t: t)
    default: break
    }
}

private enum Item {
    case digit(Int?)   // nil = blank (only ghost segments)
    case colon
    var isColon: Bool { if case .colon = self { return true } else { return false } }
}

// MARK: - Screensaver view

@objc(RetroLEDClockView)
final class RetroLEDClockView: ScreenSaverView {

    private let settings = ClockSettings()

    // Animation state
    private var startTime: CFTimeInterval = 0
    private var fade: CGFloat = 1
    private var offset = CGPoint.zero
    private var fromOffset = CGPoint.zero
    private var toOffset = CGPoint.zero
    private var moveStart: CFTimeInterval = -1000
    private let moveDuration: CFTimeInterval = 4.0
    private var lastMoveMinute = -1
    private var lastHalfSecond = -1

    // Config sheet
    private var configWindow: NSWindow?
    private var themePopup: NSPopUpButton!
    private var check24: NSButton!
    private var checkSeconds: NSButton!
    private var checkAMPM: NSButton!
    private var checkBlink: NSButton!
    private var checkBurnIn: NSButton!
    private var checkPanel: NSButton!
    private var sizeSlider: NSSlider!
    private var brightSlider: NSSlider!

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        animationTimeInterval = 1.0 / 30.0
        // Since macOS 14 the legacyScreenSaver host keeps instances alive after the
        // screensaver is dismissed; quit cleanly so stale copies don't pile up.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(screenSaverWillStop(_:)),
            name: NSNotification.Name("com.apple.screensaver.willstop"), object: nil)
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func screenSaverWillStop(_ note: Notification) {
        guard !isPreview else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exit(0) }
    }

    // MARK: Animation

    private static func currentMinute() -> Int { Int(Date().timeIntervalSince1970 / 60) }

    private static func randomOffset() -> CGPoint {
        CGPoint(x: CGFloat.random(in: -1...1), y: CGFloat.random(in: -1...1))
    }

    override func startAnimation() {
        super.startAnimation()
        startTime = CACurrentMediaTime()
        fade = 0
        offset = settings.burnIn ? Self.randomOffset() : .zero
        fromOffset = offset
        toOffset = offset
        moveStart = -1000
        lastMoveMinute = Self.currentMinute()
        needsDisplay = true
    }

    override func animateOneFrame() {
        let now = CACurrentMediaTime()
        var dirty = false

        // Fade in on start
        if fade < 1 {
            fade = CGFloat(min(1, (now - startTime) / 1.5))
            dirty = true
        }

        // Burn-in protection: glide to a new spot every minute
        if settings.burnIn {
            let minute = Self.currentMinute()
            if minute != lastMoveMinute {
                lastMoveMinute = minute
                fromOffset = offset
                toOffset = Self.randomOffset()
                moveStart = now
            }
            let t = (now - moveStart) / moveDuration
            if t < 1 {
                let e = CGFloat(t * t * (3 - 2 * t))   // smoothstep
                offset = CGPoint(x: fromOffset.x + (toOffset.x - fromOffset.x) * e,
                                 y: fromOffset.y + (toOffset.y - fromOffset.y) * e)
                dirty = true
            } else if offset != toOffset {
                offset = toOffset
                dirty = true
            }
        } else if offset != .zero {
            offset = .zero
            dirty = true
        }

        // Redraw on every half second (time change + colon blink)
        let half = Int(Date().timeIntervalSince1970 * 2)
        if half != lastHalfSecond {
            lastHalfSecond = half
            dirty = true
        }

        if dirty { needsDisplay = true }
    }

    // MARK: Drawing

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Time
        let now = Date()
        let comps = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
        var hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let second = comps.second ?? 0
        let frac = Double(comps.nanosecond ?? 0) / 1_000_000_000
        let isPM = hour >= 12
        let use24 = settings.use24h
        if !use24 {
            hour %= 12
            if hour == 0 { hour = 12 }
        }

        var items: [Item] = [
            .digit((!use24 && hour < 10) ? nil : hour / 10),
            .digit(hour % 10),
            .colon,
            .digit(minute / 10),
            .digit(minute % 10),
        ]
        if settings.showSeconds {
            items += [.colon, .digit(second / 10), .digit(second % 10)]
        }
        let showAMPM = !use24 && settings.showAMPM

        // Layout, in units of one digit width
        let spacing: CGFloat = 0.30
        let colonW: CGFloat = 0.42
        let ampmW: CGFloat = 0.95
        let digitHU: CGFloat = 1.75
        let pad: CGFloat = 0.45

        var contentU = items.reduce(CGFloat(0)) { $0 + ($1.isColon ? colonW : 1) }
            + spacing * CGFloat(items.count - 1)
        if showAMPM { contentU += ampmW + spacing }
        let panelWU = contentU + pad * 2
        let panelHU = digitHU + pad * 2

        let size = CGFloat(max(0.15, min(0.95, settings.size)))
        var w = bounds.width * size / panelWU
        w = min(w, bounds.height * 0.8 / panelHU)
        let panelW = panelWU * w, panelH = panelHU * w
        let freeX = max(0, bounds.width - panelW) / 2
        let freeY = max(0, bounds.height - panelH) / 2
        let cx = bounds.midX + offset.x * freeX * 0.92
        let cy = bounds.midY + offset.y * freeY * 0.92
        let panel = CGRect(x: cx - panelW / 2, y: cy - panelH / 2, width: panelW, height: panelH)
            .integral

        let showPanel = settings.showPanel
        let theme = kThemes[settings.theme].color
        let lit = theme.cgColor
        let ghost = theme.withAlphaComponent(0.075).cgColor
        let glow = theme.withAlphaComponent(0.85).cgColor

        ctx.saveGState()
        ctx.setAlpha(fade * CGFloat(max(0.2, min(1, settings.brightness))))

        // Panel
        if showPanel {
            let radius = w * 0.18
            let panelPath = CGPath(roundedRect: panel, cornerWidth: radius, cornerHeight: radius, transform: nil)
            ctx.addPath(panelPath)
            ctx.setFillColor(NSColor(white: 0.055, alpha: 1).cgColor)
            ctx.fillPath()
            ctx.addPath(panelPath)
            ctx.setStrokeColor(NSColor(white: 1, alpha: 0.06).cgColor)
            ctx.setLineWidth(max(1, w * 0.015))
            ctx.strokePath()
        }

        // Segments
        let t = w * 0.17
        let dh = digitHU * w
        var x = panel.minX + pad * w
        let y = panel.minY + pad * w
        let litPath = CGMutablePath()
        let ghostPath = CGMutablePath()

        if showAMPM {
            drawAMPM(ctx: ctx, origin: CGPoint(x: x, y: y), w: w, h: dh, isPM: isPM, theme: theme, showGhost: showPanel)
            x += (ampmW + spacing) * w
        }

        let colonOn = !settings.blinkColon || frac < 0.5
        for item in items {
            switch item {
            case .digit(let value):
                let on = value.map { Set(kDigitSegments[$0]) } ?? []
                for seg in 0..<7 {
                    addSegment(seg, to: on.contains(seg) ? litPath : ghostPath,
                               o: CGPoint(x: x, y: y), w: w, h: dh, t: t)
                }
                x += (1 + spacing) * w
            case .colon:
                let d = t * 1.05
                let ccx = x + colonW * w / 2
                for fy in [0.31, 0.69] as [CGFloat] {
                    let r = CGRect(x: ccx - d / 2, y: y + dh * fy - d / 2, width: d, height: d)
                    (colonOn ? litPath : ghostPath).addEllipse(in: r)
                }
                x += (colonW + spacing) * w
            }
        }

        if showPanel {
            ctx.addPath(ghostPath)
            ctx.setFillColor(ghost)
            ctx.fillPath()
        }

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: w * 0.28, color: glow)
        ctx.addPath(litPath)
        ctx.setFillColor(lit)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.restoreGState()
    }

    private func drawAMPM(ctx: CGContext, origin: CGPoint, w: CGFloat, h: CGFloat, isPM: Bool, theme: NSColor, showGhost: Bool) {
        let font = NSFont.systemFont(ofSize: w * 0.27, weight: .semibold)
        let dot = w * 0.15
        for (label, fy, active) in [("AM", CGFloat(0.70), !isPM), ("PM", CGFloat(0.30), isPM)] {
            if !active && !showGhost { continue }
            let color = active ? theme : theme.withAlphaComponent(0.22)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let str = NSAttributedString(string: label, attributes: attrs)
            let sz = str.size()
            let cy = origin.y + h * fy
            str.draw(at: CGPoint(x: origin.x, y: cy - sz.height / 2))

            let r = CGRect(x: origin.x + w * 0.95 - dot, y: cy - dot / 2, width: dot, height: dot)
            ctx.saveGState()
            if active { ctx.setShadow(offset: .zero, blur: w * 0.2, color: theme.withAlphaComponent(0.85).cgColor) }
            ctx.setFillColor(active ? theme.cgColor : theme.withAlphaComponent(0.075).cgColor)
            ctx.fillEllipse(in: r)
            ctx.restoreGState()
        }
    }

    // MARK: Options sheet

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        if configWindow == nil { configWindow = makeConfigWindow() }
        loadControls()
        return configWindow
    }

    private func swatch(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { r in
            color.setFill()
            NSBezierPath(ovalIn: r.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
    }

    private func makeConfigWindow() -> NSWindow {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 380),
                           styleMask: [.titled], backing: .buffered, defer: false)
        win.title = "Retro LED Clock"

        themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for (i, theme) in kThemes.enumerated() {
            themePopup.addItem(withTitle: theme.name)
            themePopup.item(at: i)?.image = swatch(theme.color)
        }
        check24 = NSButton(checkboxWithTitle: "24-hour time", target: nil, action: nil)
        checkSeconds = NSButton(checkboxWithTitle: "Show seconds", target: nil, action: nil)
        checkAMPM = NSButton(checkboxWithTitle: "Show AM/PM indicator (12-hour)", target: nil, action: nil)
        checkBlink = NSButton(checkboxWithTitle: "Blink colon", target: nil, action: nil)
        checkPanel = NSButton(checkboxWithTitle: "Show background panel & unlit segments", target: nil, action: nil)
        checkBurnIn = NSButton(checkboxWithTitle: "Burn-in protection (moves clock each minute)", target: nil, action: nil)
        sizeSlider = NSSlider(value: 0.5, minValue: 0.2, maxValue: 0.95, target: nil, action: nil)
        brightSlider = NSSlider(value: 1, minValue: 0.25, maxValue: 1, target: nil, action: nil)
        sizeSlider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        brightSlider.widthAnchor.constraint(equalToConstant: 220).isActive = true

        func row(_ label: String, _ control: NSView) -> NSStackView {
            let l = NSTextField(labelWithString: label)
            l.alignment = .right
            l.widthAnchor.constraint(equalToConstant: 80).isActive = true
            let s = NSStackView(views: [l, control])
            s.orientation = .horizontal
            s.spacing = 10
            return s
        }

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelConfig(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let ok = NSButton(title: "OK", target: self, action: #selector(saveConfig(_:)))
        ok.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [spacer, cancel, ok])
        buttons.orientation = .horizontal
        buttons.spacing = 10

        let stack = NSStackView(views: [
            row("Color", themePopup),
            row("Size", sizeSlider),
            row("Brightness", brightSlider),
            checkPanel, check24, checkSeconds, checkAMPM, checkBlink, checkBurnIn,
            buttons,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.setCustomSpacing(20, after: checkBurnIn)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -20),
        ])
        win.contentView = content
        win.setContentSize(stack.fittingSize)
        return win
    }

    private func loadControls() {
        themePopup.selectItem(at: settings.theme)
        check24.state = settings.use24h ? .on : .off
        checkSeconds.state = settings.showSeconds ? .on : .off
        checkAMPM.state = settings.showAMPM ? .on : .off
        checkBlink.state = settings.blinkColon ? .on : .off
        checkBurnIn.state = settings.burnIn ? .on : .off
        checkPanel.state = settings.showPanel ? .on : .off
        sizeSlider.doubleValue = settings.size
        brightSlider.doubleValue = settings.brightness
    }

    private func closeSheet() {
        guard let w = configWindow else { return }
        if let parent = w.sheetParent {
            parent.endSheet(w)
        } else {
            w.orderOut(nil)
        }
    }

    @objc private func saveConfig(_ sender: Any?) {
        settings.theme = themePopup.indexOfSelectedItem
        settings.use24h = check24.state == .on
        settings.showSeconds = checkSeconds.state == .on
        settings.showAMPM = checkAMPM.state == .on
        settings.blinkColon = checkBlink.state == .on
        settings.burnIn = checkBurnIn.state == .on
        settings.showPanel = checkPanel.state == .on
        settings.size = sizeSlider.doubleValue
        settings.brightness = brightSlider.doubleValue
        settings.save()
        closeSheet()
        needsDisplay = true
    }

    @objc private func cancelConfig(_ sender: Any?) {
        closeSheet()
    }
}
