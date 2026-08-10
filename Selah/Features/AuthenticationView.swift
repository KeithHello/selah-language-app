import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false

    var body: some View {
        VStack(spacing: SelahSpacing.xl) {
            Spacer()
            Text("Selah")
                .font(.selahDisplayLarge)
            Text(isCreatingAccount ? "建立你的學習資料空間" : "登入以繼續學習")
                .selahBodyLarge()

            VStack(spacing: SelahSpacing.md) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif
                SecureField("密碼（至少 6 個字元）", text: $password)
                    .textContentType(isCreatingAccount ? .newPassword : .password)
            }
            .textFieldStyle(.roundedBorder)

            if let message = appState.authenticationError {
                Text(message)
                    .selahBodySmall()
                    .foregroundColor(.selahCoral)
            }

            Button(isCreatingAccount ? "建立帳號" : "登入") {
                Task {
                    if isCreatingAccount {
                        await appState.signUp(email: email, password: password)
                    } else {
                        await appState.signIn(email: email, password: password)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.selahCoral)
            .disabled(appState.isAuthenticating || email.isEmpty || password.count < 6)

            Button(isCreatingAccount ? "已有帳號？登入" : "第一次使用？建立帳號") {
                isCreatingAccount.toggle()
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(SelahSpacing.page)
        .background(Color.selahBgPrimary)
    }
}

struct MissingRuntimeConfigurationView: View {
    var body: some View {
        VStack(spacing: SelahSpacing.lg) {
            Text("Selah 尚未設定服務")
                .font(.selahDisplayMedium)
            Text("請在 App 的建置環境提供 SELAH_SUPABASE_URL 與 SELAH_SUPABASE_PUBLISHABLE_KEY。應用程式不會退回模擬資料。")
                .selahBodyMedium()
                .multilineTextAlignment(.center)
        }
        .padding(SelahSpacing.page)
        .background(Color.selahBgPrimary)
    }
}
