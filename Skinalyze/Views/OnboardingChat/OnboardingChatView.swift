//
//  OnboardingChatView.swift
//  Skinalyze
//
//  Created by Heical Chandra on 09/10/24.
//

import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let role: ChatRole
    var isLast: Bool!
}

enum ChatRole {
    case system, user
}

struct ChatView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hello! Welcome to Skinalyze. Please tell us about yourself so we can get to know you better 😊", role: .system, isLast: false),
        ChatMessage(text: "What's your name?", role: .system, isLast: false),
        ChatMessage(text: "Asking for your name helps us personalize profile. Don't worry, your privacy is important to us and we'll keep your details safe 😉", role: .system, isLast: true)
    ]
    var isFromStartup: Bool
    
    @State private var inputText: String = ""
    @State private var inputAge: Int? = nil // Store integer for age input
    @State private var currentQuestionIndex = 0
    @State private var showLoading: Bool = false
    @State private var showOptions: Bool = true
    
    @EnvironmentObject var router: Router
    

    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userAge") private var userAge: Int = 17 // Change to Int
    @AppStorage("userGender") private var userGender: String = ""
    @AppStorage("skinType") private var skinType: String = ""
    @AppStorage("skinSensitivity") private var skinSensitivity: String = ""
    @AppStorage("useSkincare") private var useSkincare: String = ""
    
    @State private var scrollToBottom: Bool = false
    
    let ageRange = 0...100

    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Color(.white.opacity(0.0))
                            .frame(height: 10)
                        ForEach(messages) { message in
                            MessageRow(message: message)
//                            .padding(.trailing)
                            .id(message.id) // Beri ID untuk scroll ke posisi ini
                        }
                        
                        if showLoading {
                            TypingIndicator()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 10)
                                .id("typingIndicator")
                        }
                        
//                        Spacer().frame(height: 100)
                    }
                    Color(.white.opacity(0.0))
                        .frame(height: 50)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal)
                .padding(.bottom, -10)
                .onChange(of: messages.count) { _ in
                    // Jika ada opsi yang muncul, scroll ke bawah
                    if showOptions {
                        withAnimation {
                            scrollViewProxy.scrollTo("options", anchor: .bottom)
                        }
                    }
                    withAnimation {
                        scrollViewProxy.scrollTo("typingIndicator", anchor: .bottom)
                    }
                    if let lastMessage = messages.last {
                        withAnimation {
                            scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                    withAnimation {
                        scrollViewProxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            
            }
            
            
            if currentQuestionIndex == 0, showOptions {
                HStack {
                    HStack {
                        TextField("Please type your answer here...", text: $inputText)
                            .padding(12)
                            .background(Color.white)
                        Button(action: {
                            handleUserInput(inputText, inputMsg: inputText)
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.gray)
                                .padding(10)
                                .padding(.horizontal)
                        }
                    }
                    .background(.white)
                    .cornerRadius(30)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                }
                .padding()
                .background(Color("brownPrimary"))
            } else if currentQuestionIndex == 1, showOptions {
                HStack {
                    HStack {
                        TextField("Enter your age", value: $inputAge, format: .number) // Accept integer input
                            .keyboardType(.numberPad) // Only numeric input
                            .padding(12)
                            .background(Color.white)
                        Button(action: {
                            if let age = inputAge {
                                handleUserInput(String(age), inputMsg: String(age)) // Convert integer to string
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.gray)
                                .padding(10)
                                .padding(.horizontal)
                        }
                    }
                    .background(.white)
                    .cornerRadius(30)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                }
                .padding()
                .background(Color("brownPrimary"))
            } else if currentQuestionIndex == 2, showOptions { // Gender
                VStack(spacing: 10) {
                    Button(action: {
                        handleUserInput("Female", inputMsg: "Female")
                    }) {
                        Text("Female")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }

                    Button(action: {
                        handleUserInput("Male", inputMsg: "Male")
                    }) {
                        Text("Male")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(20)
                .background(Color("brownPrimary"))

            } else if currentQuestionIndex == 3, showOptions {
                VStack(spacing: 10) {
                    Button(action: {
                        handleUserInput("Dry", inputMsg: "Dry. Dry skin often feels tight and look flaky")
                    }) {
                        Text("Dry. Dry skin often feels tight and look flaky")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }

                    Button(action: {
                        handleUserInput("Oily", inputMsg: "Oily. Oily skin is shiny all over face with large pores")
                    }) {
                        Text("Oily. Oily skin is shiny all over face with large pores")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    Button(action: {
                        handleUserInput("Combination", inputMsg: "Combination. Combination skin looks shiny in some ares (T-zone) and feel tight on other areas")
                    }) {
                        Text("Combination. Combination skin looks shiny in some ares (T-zone) and feel tight on other areas")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(20)
                .background(Color("brownPrimary"))

            } else if currentQuestionIndex == 4, showOptions { // Skin Sensitivity
                VStack(spacing: 10) {
                    Button(action: {
                        handleUserInput("Very Sensitive", inputMsg: "Very Sensitive. Often reacts with redness, itching, or stinging when try new products")
                    }) {
                        Text("Very Sensitive. Often reacts with redness, itching, or stinging when try new products")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }

                    Button(action: {
                        handleUserInput("Only Sometimes", inputMsg: "Only Sometimes. Can handle most products, but sometimes experience irritation")
                    }) {
                        Text("Only Sometimes. Can handle most products, but sometimes experience irritation")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    Button(action: {
                        handleUserInput("Not Sensitive", inputMsg:"Not Sensitive. Rarely reacts to new products")
                    }) {
                        Text("Not Sensitive. Rarely reacts to new products")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(20)
                .background(Color("brownPrimary"))
            } else if currentQuestionIndex == 5, showOptions { // Use Skincare
                VStack(spacing: 10) {
                        Text("Yes")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            .onTapGesture {
                                router.navigate(to: .productUsedView(isFromStartup: true))
                                useSkincare = "Yes"
                            }
                        Text("No")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .foregroundColor(.black)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            .onTapGesture {
                                router.navigate(to: .camScanView)
                                useSkincare = "No"
                            }
                }
                .padding(20)
                .background(Color("brownPrimary"))
            }
        }
        .navigationTitle("Skinalyze")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
    
    func handleUserInput(_ input: String, inputMsg: String) {
        messages.append(ChatMessage(text: inputMsg, role: .user))
        inputText = ""
        showOptions = false
        showLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showLoading = false
            processInput(input)
        }
    }
    
    func processInput(_ input: String) {
        switch currentQuestionIndex {
        case 0:
            userName = input
            askNextQuestion("How old are you?", isLast: false)
            askNextQuestion("We will make sure to compare your skin condition with others in your same age group.", isLast: true)
        case 1:
            if let age = Int(input) {
                userAge = age
                askNextQuestion("What is your gender?", isLast: false)
                askNextQuestion("We will recommend you the most suitable ingredients based on your profile.", isLast: true)
            }
        case 2:
            userGender = input
            askNextQuestion("What's your skin type?", isLast: true)
        case 3:
            skinType = input
            askNextQuestion("How sensitive is your skin?", isLast: true)
        case 4:
            skinSensitivity = input
            askNextQuestion("Do you use skincare in your daily routine?", isLast: true)
//        case 5:
//            useSkincare = input
//            goToNextPage()
        default:
            break
        }
        
        currentQuestionIndex += 1
        showOptions = true
    }
    
    func askNextQuestion(_ question: String, isLast: Bool) {
        withAnimation {
            messages.append(ChatMessage(text: question, role: .system, isLast: isLast))
        }
    }
    
    func goToNextPage() {
        print("User Data: \(userName), \(userAge), \(userGender), \(skinType), \(skinSensitivity), \(useSkincare)")
        // Navigasi ke halaman berikutnya
    }
}


//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        NavigationView {
//            ChatView()
//        }
//    }
//}

//extension

struct RoundedCornerShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}


struct TypingIndicator: View {
    @State private var firstDot = false
    @State private var secondDot = false
    @State private var thirdDot = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(firstDot ? 1 : 0.5)
                .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: firstDot)
            Circle()
                .fill(Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(secondDot ? 1 : 0.5)
                .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: secondDot)
            Circle()
                .fill(Color.gray)
                .frame(width: 10, height: 10)
                .scaleEffect(thirdDot ? 1 : 0.5)
                .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4), value: thirdDot)
        }
        .onAppear {
            firstDot = true
            secondDot = true
            thirdDot = true
        }
    }
}

//#Preview{
//    ChatView(isFromStartup: )
//}


struct MessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .system {
                VStack{
                    Spacer()
                    if message.isLast {
                        Image("Maskot")
                            .resizable()
                            .frame(width: 50, height: 40)
                    } else {
                        Image("MaskotNone")
                            .resizable()
                            .frame(width: 50, height: 40)
                    }
                }
                ZStack(alignment:.bottomLeading){
                    Text(message.text)
                        .font(.body)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    Image("chatSystem")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(EdgeInsets(top: 0, leading: -5, bottom: -2, trailing: 0))
                }

            } else {
                ZStack(alignment:.bottomTrailing){
                    HStack{
                        Spacer()
                        Text(message.text)
                            .padding(14)
                            .background(Color("brownPrimary"))
                            .cornerRadius(16)
                            .frame(maxWidth: 270, alignment: .trailing)
                    }
                    Image("chatUser")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: -2, trailing: -5))
                }

            }
        }
        .padding(.trailing)
    }
}

#Preview{
    ChatView(isFromStartup: false)
}
