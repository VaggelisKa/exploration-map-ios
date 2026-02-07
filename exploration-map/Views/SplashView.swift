import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0

    private var gradientColors: [Color] {
        switch colorScheme {
        case .dark:
            return [
                Color(uiColor: .systemBackground),
                Color(uiColor: .secondarySystemBackground)
            ]
        default:
            return [
                Color(red: 0.95, green: 0.96, blue: 0.98),
                Color(red: 0.90, green: 0.93, blue: 0.97)
            ]
        }
    }

    private var iconShadowColor: Color {
        colorScheme == .dark ? .white.opacity(0.12) : .black.opacity(0.08)
    }

    private var titleColor: Color {
        colorScheme == .dark
            ? Color(white: 0.98)
            : Color(white: 0.15)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("SplashIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: iconShadowColor, radius: 20, x: 0, y: 8)

                Text("Exploration Map")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(titleColor)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                scale = 1
                opacity = 1
            }
        }
    }
}

#Preview("Light") {
    SplashView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SplashView()
        .preferredColorScheme(.dark)
}
