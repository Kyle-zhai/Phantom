import SwiftUI

/// Wraps any row content and adds iOS-style swipe-to-delete.
/// - Swipe left ≥ 40pt: reveal red delete button on trailing edge
/// - Swipe left ≥ 200pt: auto-fire the delete action
/// - Tap anywhere else / swipe right: collapse back
///
/// Built as a custom DragGesture (not List.swipeActions) so it works inside
/// our existing ScrollView + Card layout without restructuring.
struct SwipeToDelete<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isOpen = false
    @GestureState private var dragOffset: CGFloat = 0

    private let openWidth: CGFloat = 88
    private let autoFireThreshold: CGFloat = 200

    var body: some View {
        ZStack(alignment: .trailing) {
            // Red delete button revealed underneath
            Button {
                fireDelete()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Delete")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Palette.white)
                .frame(width: openWidth)
                .frame(maxHeight: .infinity)
                .background(Palette.danger)
            }
            .buttonStyle(.plain)

            // Content slides left. simultaneousGesture (not .gesture) so the
            // drag is recognized alongside the inner NavigationLink's tap —
            // tapping the row still navigates, swiping left still reveals
            // the trash button.
            content()
                .background(Palette.white)
                .contentShape(Rectangle())
                .offset(x: currentOffset)
                .simultaneousGesture(swipeGesture)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: offset)
                .overlay {
                    // When open, a transparent layer captures taps anywhere
                    // on the content and uses them to close — without this
                    // the NavigationLink tap would fire and yank the user
                    // into the detail view.
                    if isOpen {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { close() }
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }

    private var currentOffset: CGFloat {
        // While dragging: free-track. After release: snap to 0 or -openWidth.
        let combined = offset + dragOffset
        return min(0, combined)  // never goes positive
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragOffset) { value, state, _ in
                let h = value.translation.width
                // Ignore mostly-vertical gestures so vertical scroll still works
                guard abs(h) > abs(value.translation.height) else { return }
                state = isOpen ? h : min(0, h)
            }
            .onEnded { value in
                let h = value.translation.width
                guard abs(h) > abs(value.translation.height) else { return }

                let total = offset + h
                if total < -autoFireThreshold {
                    // Full swipe: fire delete with an animation that flings the row off
                    withAnimation(.easeIn(duration: 0.18)) { offset = -1000 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        fireDelete()
                    }
                } else if total < -openWidth / 2 {
                    offset = -openWidth
                    isOpen = true
                } else {
                    offset = 0
                    isOpen = false
                }
            }
    }

    private func fireDelete() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        onDelete()
    }

    private func close() {
        withAnimation { offset = 0 }
        isOpen = false
    }
}
