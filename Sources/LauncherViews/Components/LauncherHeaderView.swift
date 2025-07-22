import SwiftUI

struct LauncherHeaderView: View {
    let mode: LauncherMode
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: mode.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(mode == .launch ? .secondary : .red)
                
                Text(mode.displayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(mode == .launch ? .primary : .red)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
        )
    }
}
