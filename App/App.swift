import SwiftUI
import UIKit
import Combine

@main
struct ProjectRebuildApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { WindowGroup { RootView().tint(.cyan) } }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UIDevice.current.isBatteryMonitoringEnabled = true
        ControlServer.shared.handler = { method, path, query, body in await Routes.handle(method, path, query, body) }
        ControlServer.shared.start()
        Log.shared.add("PROJECT REBUILD launched")
        return true
    }
}

struct Habit: Identifiable, Codable, Hashable { var id = UUID(); var title: String; var category: String; var xp: Int; var completed = false; var archived = false }
struct SleepEntry: Identifiable, Codable { var id = UUID(); var date = Date(); var bedtime = Date().addingTimeInterval(-8 * 3600); var wakeTime = Date(); var quality = 5; var energy = 5; var notes = "" }
struct MoodEntry: Identifiable, Codable { var id = UUID(); var date = Date(); var mood = 5; var energy = 5; var stress = 5; var focus = 5; var journal = "" }
struct Reward: Identifiable, Codable { var id = UUID(); var title: String; var cost: Int; var redeemed = false }

@MainActor
final class RebuildStore: ObservableObject {
    static let shared = RebuildStore()
    @Published var habits: [Habit] = []
    @Published var totalXP = 0
    @Published var credits = 0
    @Published var recoveryMode = false
    @Published var sleepEntries: [SleepEntry] = []
    @Published var moodEntries: [MoodEntry] = []
    @Published var rewards: [Reward] = [Reward(title: "Favourite meal", cost: 50), Reward(title: "Gaming evening", cost: 100), Reward(title: "Solo cinema outing", cost: 150), Reward(title: "Weekend outing", cost: 250)]
    private let key = "project-rebuild-state-v1"
    private struct Snapshot: Codable { var habits: [Habit]; var totalXP: Int; var credits: Int; var recoveryMode: Bool; var sleepEntries: [SleepEntry]; var moodEntries: [MoodEntry]; var rewards: [Reward] }
    init() {
        habits = [Habit(title: "Sleep 7–9 hours", category: "Physical Health", xp: 20), Habit(title: "Wake up at the planned time", category: "Discipline", xp: 10), Habit(title: "Complete gym workout or recovery", category: "Physical Health", xp: 15), Habit(title: "Meet daily water target", category: "Physical Health", xp: 5), Habit(title: "Complete a focused session", category: "Career", xp: 10), Habit(title: "Record daily expenses", category: "Financial Health", xp: 5), Habit(title: "Connect with family", category: "Relationships", xp: 10), Habit(title: "Complete daily reflection", category: "Mental Wellbeing", xp: 10)]
        load()
    }
    var level: Int { max(1, Int(Double(totalXP) / 250.0) + 1) }
    var levelFloor: Int { (level - 1) * 250 }
    var levelProgress: Double { min(1, Double(totalXP - levelFloor) / 250.0) }
    var todayXP: Int { habits.filter { $0.completed && !$0.archived }.reduce(0) { $0 + $1.xp } }
    var completion: Double { let active = habits.filter { !$0.archived }; return active.isEmpty ? 0 : Double(active.filter(\.completed).count) / Double(active.count) }
    func toggle(_ habit: Habit) { guard let i = habits.firstIndex(of: habit) else { return }; habits[i].completed.toggle(); let amount = habits[i].xp; let creditsAmount = max(1, amount / 5); if habits[i].completed { totalXP += amount; credits += creditsAmount } else { totalXP = max(0, totalXP - amount); credits = max(0, credits - creditsAmount) }; save() }
    func addHabit(title: String, category: String, xp: Int) { habits.append(Habit(title: title, category: category, xp: max(1, xp))); save() }
    func addSleep(_ entry: SleepEntry) { sleepEntries.insert(entry, at: 0); save() }
    func addMood(_ entry: MoodEntry) { moodEntries.insert(entry, at: 0); save() }
    func redeem(_ reward: Reward) { guard credits >= reward.cost, let i = rewards.firstIndex(where: { $0.id == reward.id }) else { return }; credits -= reward.cost; rewards[i].redeemed = true; save() }
    func save() { let s = Snapshot(habits: habits, totalXP: totalXP, credits: credits, recoveryMode: recoveryMode, sleepEntries: sleepEntries, moodEntries: moodEntries, rewards: rewards); if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) } }
    private func load() { guard let data = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }; habits = s.habits; totalXP = s.totalXP; credits = s.credits; recoveryMode = s.recoveryMode; sleepEntries = s.sleepEntries; moodEntries = s.moodEntries; rewards = s.rewards }
}

enum Routes {
    static func handle(_ method: String, _ path: String, _ q: [String: String], _ body: [String: Any]) async -> (Int, Any) {
        switch (method, path) {
        case ("GET", "/ping"): return (200, ["ok": true, "app": "PROJECT REBUILD"])
        case ("GET", "/status"):
            return await MainActor.run { ["level": RebuildStore.shared.level, "totalXP": RebuildStore.shared.totalXP, "todayXP": RebuildStore.shared.todayXP, "completion": RebuildStore.shared.completion, "recoveryMode": RebuildStore.shared.recoveryMode] }
        case ("GET", "/device"):
            let d = await MainActor.run { () -> Data in (try? JSONSerialization.data(withJSONObject: ControlServer.sanitize(DeviceProbe.snapshot()))) ?? Data() }
            return (200, (try? JSONSerialization.jsonObject(with: d)) ?? [:])
        case ("GET", "/log"): return (200, ["lines": Log.shared.all()])
        default: return (404, ["error": "no route \(method) \(path)"])
        }
    }
}

struct RootView: View {
    @StateObject private var store = RebuildStore.shared
    var body: some View { TabView { DashboardView().tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }; HabitsView().tabItem { Label("Tracker", systemImage: "checklist") }; SleepView().tabItem { Label("Sleep", systemImage: "bed.double.fill") }; MoodView().tabItem { Label("Mood", systemImage: "brain.head.profile") }; RewardsView().tabItem { Label("Rewards", systemImage: "gift.fill") } }.preferredColorScheme(.dark).environmentObject(store) }
}

struct Shell: ViewModifier { func body(content: Content) -> some View { content.scrollContentBackground(.hidden).background(Color(red: 0.035, green: 0.045, blue: 0.07)).foregroundStyle(.white) } }
struct MetricCard: View { let title: String; let value: String; let detail: String; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(title).font(.caption.bold()).foregroundStyle(.secondary); Text(value).font(.title2.bold()); Text(detail).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16)) } }

struct DashboardView: View {
    @EnvironmentObject var store: RebuildStore
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 18) { Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day()).foregroundStyle(.secondary); Text(store.recoveryMode ? "Recovery protocol" : "Good morning, rebuild.").font(.largeTitle.bold()); if store.recoveryMode { Text("Progress is preserved. Focus on recovery.").foregroundStyle(.cyan) }; HStack(spacing: 12) { MetricCard(title: "LEVEL", value: "\(store.level)", detail: "\(store.totalXP) lifetime XP"); MetricCard(title: "TODAY", value: "\(store.todayXP) XP", detail: "\(Int(store.completion * 100))% complete") }; ProgressView(value: store.levelProgress).tint(.cyan).scaleEffect(y: 2); Text("Level \(store.level + 1) at \(store.levelFloor + 250) XP").font(.caption).foregroundStyle(.secondary); HStack { Text("Daily completion").font(.headline); Spacer(); Text("\(Int(store.completion * 100))%").foregroundStyle(.cyan) }; ProgressView(value: store.completion).tint(.purple); if let last = store.sleepEntries.first { MetricCard(title: "LAST SLEEP", value: String(format: "%.1fh", last.wakeTime.timeIntervalSince(last.bedtime) / 3600), detail: "Quality \(last.quality)/10") }; Toggle("Recovery Mode", isOn: Binding(get: { store.recoveryMode }, set: { store.recoveryMode = $0; store.save() })).tint(.cyan); Text("Progress, not perfection.").font(.headline).foregroundStyle(.secondary) }.padding() }.modifier(Shell()).navigationTitle("PROJECT REBUILD") } }
}

struct HabitsView: View {
    @EnvironmentObject var store: RebuildStore; @State private var showingAdd = false
    var body: some View { NavigationStack { List { ForEach(store.habits.filter { !$0.archived }) { habit in Button { store.toggle(habit) } label: { HStack { Image(systemName: habit.completed ? "checkmark.circle.fill" : "circle").foregroundStyle(habit.completed ? .green : .secondary); VStack(alignment: .leading) { Text(habit.title); Text(habit.category).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("+\(habit.xp) XP").foregroundStyle(.cyan) } } }.listRowBackground(Color.white.opacity(0.06)) }.modifier(Shell()).navigationTitle("Daily tracker").toolbar { Button { showingAdd = true } label: { Image(systemName: "plus") } }.sheet(isPresented: $showingAdd) { AddHabitView().environmentObject(store) } } }
}
struct AddHabitView: View { @EnvironmentObject var store: RebuildStore; @Environment(\.dismiss) private var dismiss; @State private var title = ""; @State private var category = "Discipline"; @State private var xp = 10; var body: some View { NavigationStack { Form { TextField("Habit name", text: $title); TextField("Category", text: $category); Stepper("\(xp) XP", value: $xp, in: 1...100) }.navigationTitle("New habit").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Add") { guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }; store.addHabit(title: title, category: category, xp: xp); dismiss() } } } } } }

struct SleepView: View { @EnvironmentObject var store: RebuildStore; @State private var bedtime = Date().addingTimeInterval(-8 * 3600); @State private var wake = Date(); @State private var quality = 5; @State private var energy = 5; var body: some View { NavigationStack { Form { Section("Last night") { DatePicker("Bedtime", selection: $bedtime, displayedComponents: [.date, .hourAndMinute]); DatePicker("Wake time", selection: $wake, displayedComponents: [.date, .hourAndMinute]); Stepper("Sleep quality: \(quality)/10", value: $quality, in: 1...10); Stepper("Morning energy: \(energy)/10", value: $energy, in: 1...10); Button("Save sleep session") { store.addSleep(SleepEntry(bedtime: bedtime, wakeTime: wake, quality: quality, energy: energy)) } }; Section("Recent sessions") { ForEach(store.sleepEntries.prefix(7)) { entry in HStack { Text(entry.date, format: .dateTime.month(.abbreviated).day()); Spacer(); Text(String(format: "%.1f hours", max(0, entry.wakeTime.timeIntervalSince(entry.bedtime) / 3600))) } } } }.modifier(Shell()).navigationTitle("Sleep") } } }
struct MoodView: View { @EnvironmentObject var store: RebuildStore; @State private var mood = 5; @State private var energy = 5; @State private var stress = 5; @State private var focus = 5; @State private var journal = ""; var body: some View { NavigationStack { Form { Section("Daily check-in") { Slider(value: Binding(get: { Double(mood) }, set: { mood = Int($0) }), in: 1...10, step: 1) { Text("Mood \(mood)/10") }; Slider(value: Binding(get: { Double(energy) }, set: { energy = Int($0) }), in: 1...10, step: 1) { Text("Energy \(energy)/10") }; Slider(value: Binding(get: { Double(stress) }, set: { stress = Int($0) }), in: 1...10, step: 1) { Text("Stress \(stress)/10") }; Slider(value: Binding(get: { Double(focus) }, set: { focus = Int($0) }), in: 1...10, step: 1) { Text("Focus \(focus)/10") }; TextField("Private journal", text: $journal, axis: .vertical); Button("Save check-in") { store.addMood(MoodEntry(mood: mood, energy: energy, stress: stress, focus: focus, journal: journal)); journal = "" } }; Section("Recent check-ins") { ForEach(store.moodEntries.prefix(7)) { entry in Text("\(entry.date.formatted(date: .abbreviated, time: .omitted)) · mood \(entry.mood)/10 · energy \(entry.energy)/10") } } }.modifier(Shell()).navigationTitle("Mood & journal") } } }
struct RewardsView: View { @EnvironmentObject var store: RebuildStore; var body: some View { NavigationStack { List { Section { Text("Available credits: \(store.credits)").font(.headline).foregroundStyle(.cyan) }; Section("Reward store") { ForEach(store.rewards) { reward in HStack { VStack(alignment: .leading) { Text(reward.title); Text("\(reward.cost) credits").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(reward.redeemed ? "Redeemed" : "Redeem") { store.redeem(reward) }.disabled(reward.redeemed || store.credits < reward.cost).buttonStyle(.borderedProminent) } } }.listRowBackground(Color.white.opacity(0.06)) }.modifier(Shell()).navigationTitle("Rewards") } }
