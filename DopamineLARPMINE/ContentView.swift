import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case dopamine = "Dopamine"
    case ocean = "Океан"
    case midnight = "Полночь"
    case aurora = "Аврора"

    var id: String { rawValue }

    var colors: [Color] {
        switch self {
        case .dopamine:
            return [Color(hex: "134B96"), Color(hex: "2B7CD6"), Color(hex: "46A0EE"), Color(hex: "0D3875")]
        case .ocean:
            return [Color(hex: "0A3D5C"), Color(hex: "147A9E"), Color(hex: "23B5C9"), Color(hex: "07273D")]
        case .midnight:
            return [Color(hex: "091124"), Color(hex: "1A2F63"), Color(hex: "2B4C96"), Color(hex: "050914")]
        case .aurora:
            return [Color(hex: "113A4F"), Color(hex: "1D7874"), Color(hex: "3AA6B9"), Color(hex: "182B49")]
        }
    }
}

struct LogItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isVerbose: Bool
    var isCompleted: Bool
}

struct ContentView: View {
    @AppStorage("isJailbroken") private var isJailbroken = false
    @AppStorage("exploit") private var exploit = "kfd"
    @AppStorage("tweakInjection") private var tweakInjection = true
    @AppStorage("verboseLogs") private var verboseLogs = false
    @AppStorage("allowJIT") private var allowJIT = true
    @AppStorage("jetsamMultiplier") private var jetsamMultiplier = "1x (По умолчанию)"
    @AppStorage("kernelPanic") private var kernelPanic = false
    @AppStorage("themeName") private var themeName = AppTheme.dopamine.rawValue
    @AppStorage("customBootlogo") private var customBootlogo = true
    @AppStorage("realRespring") private var realRespring = true

    @State private var isRunning = false
    @State private var showPackagePicker = false
    @State private var selectedPackages: Set<String> = ["Sileo"]
    @State private var logs: [LogItem] = []

    @State private var showSettings = false
    @State private var showCredits = false
    @State private var showRemoveAlert = false

    @State private var showBootOverlay = false
    @State private var bootProgress: CGFloat = 0.0
    @State private var bootRespringAfter = false

    @State private var showRespringSpinner = false

    @State private var showKernelPanic = false
    @State private var showKpConsole = false
    @State private var kpText = ""

    @State private var toastText: String? = nil

    private var currentTheme: AppTheme {
        AppTheme(rawValue: themeName) ?? .dopamine
    }

    var body: some View {
        ZStack {
            MeshBackgroundView(theme: currentTheme)
                .ignoresSafeArea()

            // Main Home Screen
            VStack(alignment: .leading, spacing: 0) {
                headerView
                    .padding(.top, 26)

                if isRunning {
                    statusBanner
                        .padding(.top, 18)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                if !isRunning {
                    homeMenuCard
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }

                Spacer()

                if !isRunning {
                    jailbreakActionButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if showPackagePicker {
                    packagePickerCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    logsView
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
            .offset(x: (showSettings || showCredits) ? -28 : 0)
            .opacity((showSettings || showCredits) ? 0 : 1)

            // Settings Screen
            if showSettings {
                SettingsView(
                    isPresented: $showSettings,
                    showCredits: $showCredits,
                    isJailbroken: $isJailbroken,
                    exploit: $exploit,
                    tweakInjection: $tweakInjection,
                    verboseLogs: $verboseLogs,
                    allowJIT: $allowJIT,
                    jetsamMultiplier: $jetsamMultiplier,
                    kernelPanic: $kernelPanic,
                    themeName: $themeName,
                    customBootlogo: $customBootlogo,
                    realRespring: $realRespring,
                    showRemoveAlert: $showRemoveAlert,
                    onToast: triggerToast
                )
                .transition(.move(edge: .trailing))
            }

            // Credits Screen
            if showCredits {
                CreditsView(isPresented: $showCredits)
                    .transition(.move(edge: .trailing))
            }

            // Boot / Userspace Reboot Overlay
            if showBootOverlay {
                bootScreenOverlay
                    .ignoresSafeArea()
                    .zIndex(50)
            }

            // Respring Spinner Overlay
            if showRespringSpinner {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                .zIndex(55)
            }

            // Kernel Panic Overlay
            if showKernelPanic {
                kernelPanicOverlay
                    .ignoresSafeArea()
                    .zIndex(60)
            }

            // Toast Notification
            if let toast = toastText {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .liquidGlass(cornerRadius: 99)
                        .padding(.bottom, 28)
                }
                .zIndex(45)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .statusBar(hidden: showBootOverlay || showRespringSpinner || showKernelPanic)
        .persistentSystemOverlays((showBootOverlay || showRespringSpinner || showKernelPanic) ? .hidden : .automatic)
        .alert("Удаление джейлбрейка", isPresented: $showRemoveAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Продолжить", role: .destructive) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    showSettings = false
                }
                startBootSequence(duration: 2.3, triggerSystemRespring: realRespring) {
                    isJailbroken = false
                }
            }
        } message: {
            Text("Удаление джейлбрейка приводит к удалению всех файлов, связанных с джейлбрейком, но все обычные приложения, файлы и данные будут сохранены. Вы уверены, что хотите продолжить? Вы не сможете отменить это действие.")
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dopamine")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.18), radius: 12)

            Text("iOS 15.0 - 27.3 (A9-A20)")
                .font(.system(size: 15.5, weight: .medium))
                .foregroundColor(.white.opacity(0.92))

            Text("LARPMINE от LinuxFromGod, оригинальный UI")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 14) {
            DNAHelixView()
                .frame(width: 28, height: 20)

            Text("Выполнение джейлбрейка")
                .font(.system(size: 15.5, weight: .medium))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .liquidGlass(cornerRadius: 17)
    }

    private var homeMenuCard: some View {
        VStack(spacing: 0) {
            MenuRowButton(icon: "gearshape", title: "Настройки", showChevron: true, disabled: false) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    showSettings = true
                }
            }

            Divider().background(Color.white.opacity(0.16))

            MenuRowButton(icon: "arrow.clockwise", title: "Перезапустить SpringBoard", showChevron: false, disabled: !isJailbroken) {
                executeRespringOnly()
            }

            Divider().background(Color.white.opacity(0.16))

            MenuRowButton(icon: "circle.circle", title: "Перезагрузить Userspace", showChevron: false, disabled: !isJailbroken) {
                startBootSequence(duration: 2.3, triggerSystemRespring: false) {
                    isJailbroken = true
                }
            }

            Divider().background(Color.white.opacity(0.16))

            MenuRowButton(icon: "info.circle", title: "Благодарности", showChevron: true, disabled: false) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    showCredits = true
                }
            }
        }
        .liquidGlass(cornerRadius: 20)
    }

    private var jailbreakActionButton: some View {
        Button {
            guard !isJailbroken && !isRunning else { return }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                isRunning = true
                showPackagePicker = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.open")
                    .font(.system(size: 17, weight: .semibold))
                Text(isJailbroken ? "Джейлбрейк выполнен" : "Джейлбрейк")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .liquidGlass(cornerRadius: 19)
            .opacity(isJailbroken ? 0.45 : 1.0)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isJailbroken)
    }

    private var packagePickerCard: some View {
        VStack(spacing: 16) {
            Text("Выберите менеджер(ы) пакетов")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 26) {
                PackageOptionView(name: "Sileo", isSelected: selectedPackages.contains("Sileo"), isZebra: false) {
                    togglePackage("Sileo")
                }
                PackageOptionView(name: "Zebra", isSelected: selectedPackages.contains("Zebra"), isZebra: true) {
                    togglePackage("Zebra")
                }
            }

            Text("Если вы не знаете, какой из них выбрать, выберите Sileo")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    showPackagePicker = false
                }
                runJailbreakLogs()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                    Text("Продолжить")
                }
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .liquidGlass(cornerRadius: 15)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .liquidGlass(cornerRadius: 22)
    }

    private var logsView: some View {
        let primaryLogs = logs.filter { !$0.isVerbose }
        return VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)
            ForEach(logs) { item in
                if item.isVerbose {
                    Text(item.text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.68))
                        .padding(.leading, 28)
                } else {
                    let idxFromBottom = (primaryLogs.count - 1) - (primaryLogs.firstIndex(of: item) ?? 0)
                    let blurRadius = idxFromBottom == 0 ? 0.0 : min(8.0, Double(idxFromBottom) * 0.65)
                    let rowOpacity = idxFromBottom == 0 ? 1.0 : max(0.08, 0.84 - Double(idxFromBottom) * 0.11)

                    HStack(spacing: 12) {
                        if item.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 18, height: 18)
                        } else {
                            ArcSpinnerView()
                                .frame(width: 18, height: 18)
                        }

                        Text(item.text)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white)
                    }
                    .blur(radius: blurRadius)
                    .opacity(rowOpacity)
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.52, alignment: .bottomLeading)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.45), location: 0.25),
                    .init(color: .black, location: 0.62),
                    .init(color: .black, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var bootScreenOverlay: some View {
        ZStack {
            Color.black
            VStack(spacing: 38) {
                if customBootlogo {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 14)
                            .frame(width: 66, height: 66)
                        Circle()
                            .trim(from: 0.45, to: 0.78)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "4DB6AC"), Color.white],
                                    startPoint: .bottomLeading,
                                    endPoint: .topTrailing
                                ),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .frame(width: 66, height: 66)
                    }
                } else {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 56))
                        .foregroundColor(.white)
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 148, height: 3.5)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 148 * bootProgress, height: 3.5)
                }
            }
        }
    }

    private var kernelPanicOverlay: some View {
        ZStack(alignment: .topLeading) {
            Color.black

            if !showKpConsole {
                VStack {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .padding(.top, UIScreen.main.bounds.height * 0.16)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(kpText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "E5E5EA"))
                    .padding(.top, 52)
                    .padding(.horizontal, 14)
            }
        }
    }

    // MARK: - Logic

    private func togglePackage(_ pkg: String) {
        if selectedPackages.contains(pkg) {
            if selectedPackages.count > 1 {
                selectedPackages.remove(pkg)
            }
        } else {
            selectedPackages.insert(pkg)
        }
    }

    private func triggerToast(_ msg: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            toastText = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation {
                if toastText == msg { toastText = nil }
            }
        }
    }

    private func runJailbreakLogs() {
        logs.removeAll()
        let pkgList = selectedPackages.sorted().joined(separator: ", ")
        let steps: [(String, String)] = [
            ("Загрузка ядра", "[kernel] mapping mach_header @ 0xfffffe0007004000"),
            ("Поиск патчей", "[patchfinder] PPL/SPTM gadgets resolved (14/14)"),
            ("Эксплуатация ядра (\(exploit), landa)", "[\(exploit)] reclaiming IOSurface kalloc.16384"),
            ("Обход SPTM (dmaFail)", "[sptm] page table frame locked via DMA window"),
            ("Создание R/W примитива", "[krw] kread64 / kwrite64 stable"),
            ("Очистка эксплойтов", "[cleanup] dangling descriptors restored"),
            ("Повышение прав", "[cred] proc->p_ucred->cr_uid = 0 (root)"),
            ("Extracting Bootstrap", "[bootstrap] unpacking procursus (\(pkgList))"),
            ("Finalizing Bootstrap", "[bootstrap] symlinks & dpkg status verified"),
            ("Получение кэша доверия BaseBin", "[trustcache] loaded 42 cdhashes into PPL"),
            ("Инициализация среды", "[env] /var/jb/usr/bin mounted"),
            ("Инициализация защиты", "[launchdhook] injecting systemwide hook"),
            ("Применение монтирования с правами записи", "[mount] bindfs /var/jb -> /private/preboot"),
            ("Проверка дубликатов приложений", "[uicache] refreshing SpringBoard icon layout")
        ]

        func appendStep(_ index: Int) {
            if let lastIdx = logs.lastIndex(where: { !$0.isVerbose && !$0.isCompleted }) {
                logs[lastIdx].isCompleted = true
            }

            guard index < steps.count else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    finishJailbreak()
                }
                return
            }

            let step = steps[index]
            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                logs.append(LogItem(text: step.0, isVerbose: false, isCompleted: false))
                if verboseLogs {
                    logs.append(LogItem(text: step.1, isVerbose: true, isCompleted: true))
                }
            }

            let delay = Double.random(in: 0.36...0.58)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                appendStep(index + 1)
            }
        }

        appendStep(0)
    }

    private func finishJailbreak() {
        if kernelPanic {
            runKernelPanicSequence()
        } else {
            isJailbroken = true
            if realRespring {
                // Real iOS backboardd respring!
                RespringManager.shared.triggerRealRespring()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isRunning = false
                    logs.removeAll()
                }
            } else {
                startBootSequence(duration: 2.2, triggerSystemRespring: false) {
                    isRunning = false
                    logs.removeAll()
                }
            }
        }
    }

    private func executeRespringOnly() {
        guard isJailbroken else { return }
        if realRespring {
            RespringManager.shared.triggerRealRespring()
        } else {
            showRespringSpinner = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                showRespringSpinner = false
            }
        }
    }

    private func startBootSequence(duration: Double, triggerSystemRespring: Bool, completion: @escaping () -> Void) {
        if triggerSystemRespring {
            completion()
            RespringManager.shared.triggerRealRespring()
            return
        }

        bootProgress = 0.0
        withAnimation(.easeIn(duration: 0.25)) {
            showBootOverlay = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: duration)) {
                bootProgress = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
            completion()
            withAnimation(.easeOut(duration: 0.28)) {
                showBootOverlay = false
            }
        }
    }

    private func runKernelPanicSequence() {
        showKpConsole = false
        kpText = ""
        showKernelPanic = true

        let panicLines = [
            "panic(cpu 3 caller 0xfffffe001c492a14): \"AMFI: code signature invalid in /var/jb/basebin/launchdhook.dylib\"",
            "Debugger message: panic",
            "Memory ID: 0x6",
            "OS release type: User",
            "OS version: 24A335",
            "Kernel version: Darwin Kernel Version 26.0.0: Tue Oct 14 21:18:42 PDT 2026; root:xnu-11417.40.12~1/RELEASE_ARM64_T8130",
            "KernelCache UUID: 8F9A2C1D4E7B3A609C5D2E1F8A7B4C3D",
            "Boot session UUID: E4B1A9C2-7D3F-4E8A-9B2C-1F6D8A4E5C7B",
            "iBoot version: iBoot-11881.40.9",
            "secure boot?: YES",
            "Paniclog version: 14",
            "Kernel slide:      0x0000000014200000",
            "Kernel text base:  0xfffffe001b204000",
            "mach_absolute_time: 0x00000019a4f821c0",
            "CORE 0: PC=0xfffffe001b389120, LR=0xfffffe001b3890f4, FP=0xfffffe608b413e10",
            "CORE 1: PC=0xfffffe001b389120, LR=0xfffffe001b3890f4, FP=0xfffffe608b41be10",
            "CORE 2 is the one that panicked. Check the full backtrace for details.",
            "CORE 3: PC=0xfffffe001b412c88, LR=0xfffffe001b412c40, FP=0xfffffe608b42be10",
            "",
            "** PANIC CPU 2: waiting for debugger or reboot **"
        ]

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            showKpConsole = true
            for (idx, line) in panicLines.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.07) {
                    kpText += line + "\n"
                }
            }

            let totalPrintTime = Double(panicLines.count) * 0.07 + 1.1
            DispatchQueue.main.asyncAfter(deadline: .now() + totalPrintTime) {
                showKernelPanic = false
                startBootSequence(duration: 2.2, triggerSystemRespring: false) {
                    isJailbroken = false
                    isRunning = false
                    logs.removeAll()
                }
            }
        }
    }
}

// MARK: - Settings Screen

struct SettingsView: View {
    @Binding var isPresented: Bool
    @Binding var showCredits: Bool
    @Binding var isJailbroken: Bool
    @Binding var exploit: String
    @Binding var tweakInjection: Bool
    @Binding var verboseLogs: Bool
    @Binding var allowJIT: Bool
    @Binding var jetsamMultiplier: String
    @Binding var kernelPanic: Bool
    @Binding var themeName: String
    @Binding var customBootlogo: Bool
    @Binding var realRespring: Bool
    @Binding var showRemoveAlert: Bool
    var onToast: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    isPresented = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Назад")
                        .font(.system(size: 16.5, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.vertical, 6)
            }
            .padding(.top, 10)

            Text("Настройки")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 6)
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // ЭКСПЛОЙТЫ
                    SettingsSection(title: "ЭКСПЛОЙТЫ") {
                        Menu {
                            ForEach(["kfd", "landa", "dmaFail"], id: \.self) { item in
                                Button {
                                    exploit = item
                                } label: {
                                    if exploit == item {
                                        Label(item, systemImage: "checkmark")
                                    } else {
                                        Text(item)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text("Эксплойт Ядра")
                                    .foregroundColor(.white)
                                Spacer()
                                Text(exploit)
                                    .foregroundColor(.white.opacity(0.6))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                    }

                    // НАСТРОЙКИ ДЖЕЙЛБРЕЙКА
                    SettingsSection(title: "НАСТРОЙКИ ДЖЕЙЛБРЕЙКА") {
                        ToggleRow(title: "Внедрение твиков", isOn: $tweakInjection)
                        Divider().background(Color.white.opacity(0.14))
                        ToggleRow(title: "Расширенные логи", isOn: $verboseLogs)
                        Divider().background(Color.white.opacity(0.14))
                        ToggleRow(title: "Разрешить JIT в приложениях", isOn: $allowJIT)
                        Divider().background(Color.white.opacity(0.14))

                        Menu {
                            ForEach(["1x (По умолчанию)", "2x", "3x", "4x"], id: \.self) { mult in
                                Button {
                                    jetsamMultiplier = mult
                                } label: {
                                    if jetsamMultiplier == mult {
                                        Label(mult, systemImage: "checkmark")
                                    } else {
                                        Text(mult)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text("Множитель Jetsam")
                                    .foregroundColor(.white)
                                Spacer()
                                Text(jetsamMultiplier)
                                    .foregroundColor(.white.opacity(0.6))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }

                        Divider().background(Color.white.opacity(0.14))

                        Button {
                            if isJailbroken {
                                showRemoveAlert = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                Text("Удалить джейлбрейк")
                                Spacer()
                            }
                            .foregroundColor(Color(hex: "FF453A"))
                            .font(.system(size: 16, weight: .medium))
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .opacity(isJailbroken ? 1.0 : 0.35)
                        }
                        .disabled(!isJailbroken)
                    }

                    // СИМУЛЯЦИЯ И РЕСПРИНГ
                    SettingsSection(
                        title: "СИМУЛЯЦИЯ",
                        footer: "Реальный респринг перезапускает SpringBoard/backboardd через iOS Jetsam в конце джейлбрейка. Kernel Panic имитирует сбой и сбрасывает статус."
                    ) {
                        ToggleRow(title: "Реальный респринг iOS", isOn: $realRespring)
                        Divider().background(Color.white.opacity(0.14))
                        ToggleRow(title: "Kernel Panic", isOn: $kernelPanic)
                    }

                    // КАСТОМИЗАЦИЯ
                    SettingsSection(title: "КАСТОМИЗАЦИЯ") {
                        Menu {
                            ForEach(AppTheme.allCases) { t in
                                Button {
                                    themeName = t.rawValue
                                } label: {
                                    if themeName == t.rawValue {
                                        Label(t.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(t.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text("Темы")
                                    .foregroundColor(.white)
                                Spacer()
                                Text(themeName)
                                    .foregroundColor(.white.opacity(0.6))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }

                        Divider().background(Color.white.opacity(0.14))
                        ToggleRow(title: "Собственный bootlogo", isOn: $customBootlogo)
                        Divider().background(Color.white.opacity(0.14))

                        Menu {
                            Button("Переустановить Sileo") { onToast("Sileo переустановлен") }
                            Button("Переустановить Zebra") { onToast("Zebra переустановлен") }
                        } label: {
                            HStack {
                                Text("Переустановить менеджер пакетов")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                    }

                    // ДЕЙСТВИЯ
                    SettingsSection(title: "ДЕЙСТВИЯ") {
                        Button {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                isPresented = false
                                showCredits = true
                            }
                        } label: {
                            HStack {
                                Text("Благодарности")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }

                        Divider().background(Color.white.opacity(0.14))

                        Button {
                            exploit = "kfd"
                            tweakInjection = true
                            verboseLogs = false
                            allowJIT = true
                            jetsamMultiplier = "1x (По умолчанию)"
                            kernelPanic = false
                            themeName = AppTheme.dopamine.rawValue
                            customBootlogo = true
                            realRespring = true
                            onToast("Настройки сброшены")
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Сбросить настройки")
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .padding(.horizontal, 22)
    }
}

struct CreditsView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    isPresented = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Назад")
                        .font(.system(size: 16.5, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.vertical, 6)
            }
            .padding(.top, 10)

            Text("Благодарности")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 6)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 8) {
                Text("LARPMINE 3.0.13 - Simulation")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundColor(.white)
                Text("Симулятор джейлбрейка Dopamine на SwiftUI с Liquid Glass интерфейсом, реальным iOS респрингом и симуляцией Kernel Panic.")
                    .font(.system(size: 13.5))
                    .foregroundColor(.white.opacity(0.75))
                    .lineSpacing(3)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: 20)

            Spacer()
        }
        .padding(.horizontal, 22)
    }
}

// MARK: - Reusable Components & Liquid Glass Modifier

struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
                .padding(.leading, 14)

            VStack(spacing: 0) {
                content()
            }
            .liquidGlass(cornerRadius: 20)

            if let footer = footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.52))
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .tint(Color(hex: "30D158"))
        .padding(.horizontal, 16)
        .frame(height: 50)
    }
}

struct MenuRowButton: View {
    let icon: String
    let title: String
    let showChevron: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 16))
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .frame(height: 54)
            .opacity(disabled ? 0.38 : 1.0)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(disabled)
    }
}

struct PackageOptionView: View {
    let name: String
    let isSelected: Bool
    let isZebra: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if isZebra {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "1C1C1E"), Color(hex: "F2F2F7"), Color(hex: "1C1C1E"), Color(hex: "F2F2F7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 74, height: 74)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "27A4FF"), Color(hex: "0D6EFD"), Color(hex: "00C6D7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 74, height: 74)
                            .overlay(
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            )
                    }

                    ZStack {
                        Circle()
                            .fill(isSelected ? Color(hex: "0A84FF") : Color.black.opacity(0.65))
                            .frame(width: 23, height: 23)
                        Circle()
                            .stroke(Color.white.opacity(isSelected ? 1.0 : 0.6), lineWidth: 1.5)
                            .frame(width: 23, height: 23)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(x: 4, y: 4)
                }

                Text(name)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct DNAHelixView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let phase = timeline.date.timeIntervalSinceReferenceDate * 4.5
                let cols = 7
                for i in 0..<cols {
                    let x = 4.0 + Double(i) * 3.4
                    let angle = phase + Double(i) * 0.68
                    let y1 = size.height / 2 + sin(angle) * 6.5
                    let y2 = size.height / 2 - sin(angle) * 6.5
                    let z1 = cos(angle)
                    let z2 = -z1

                    var line = Path()
                    line.move(to: CGPoint(x: x, y: y1))
                    line.addLine(to: CGPoint(x: x, y: y2))
                    context.stroke(line, with: .color(.white.opacity(0.28)), lineWidth: 1.1)

                    let r1 = 1.4 + z1 * 0.4
                    let rect1 = CGRect(x: x - r1, y: y1 - r1, width: r1 * 2, height: r1 * 2)
                    context.fill(Path(ellipseIn: rect1), with: .color(.white.opacity(0.55 + 0.45 * ((z1 + 1) / 2))))

                    let r2 = 1.4 + z2 * 0.4
                    let rect2 = CGRect(x: x - r2, y: y2 - r2, width: r2 * 2, height: r2 * 2)
                    context.fill(Path(ellipseIn: rect2), with: .color(.white.opacity(0.55 + 0.45 * ((z2 + 1) / 2))))
                }
            }
        }
    }
}

struct ArcSpinnerView: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 2)
            Circle()
                .trim(from: 0.0, to: 0.3)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 0.85).repeatForever(autoreverses: false), value: spin)
        }
        .onAppear { spin = true }
    }
}

struct MeshBackgroundView: View {
    let theme: AppTheme
    @State private var animate = false

    var body: some View {
        ZStack {
            theme.colors[0]

            Circle()
                .fill(theme.colors[1])
                .frame(width: 340, height: 340)
                .blur(radius: 68)
                .offset(x: animate ? -40 : -90, y: animate ? -140 : -210)

            Circle()
                .fill(theme.colors[2])
                .frame(width: 320, height: 320)
                .blur(radius: 68)
                .offset(x: animate ? 80 : 130, y: animate ? -30 : -90)

            Circle()
                .fill(theme.colors[3])
                .frame(width: 360, height: 360)
                .blur(radius: 72)
                .offset(x: animate ? -60 : -110, y: animate ? 180 : 240)
        }
        .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: animate)
        .onAppear { animate = true }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.972 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat) -> some View {
        self
            .background(.ultraThinMaterial.opacity(0.55))
            .background(Color.white.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.38), .white.opacity(0.12), .white.opacity(0.24)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
