//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/15/22.
//

import Core
import SwiftUI
import ComposableArchitecture

struct CardView: View {
    let hymn: Hymnal
    
    init(_ hymn: Hymnal) {
        self.hymn = hymn
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hymn.title)
                .font(.customBody)
            Text(hymn.subtitle)
                .font(.customCaption)
        }.background(
            RoundedRectangle(cornerRadius: 12)
                .foregroundColor(.random)
                .shadow(radius: 3)
        )
        .frame(height: 20)
    }
}

extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}


public struct MockStore {
    public static var cards = [
        Hymnal.allCases[0],
        Hymnal.allCases[1],
        Hymnal.allCases[2],
    ]
}


public struct LanguageView: View {
    
    let store: Store<LanguagePickerState, LanguagePickerAction>
    
    public init(store: Store<LanguagePickerState, LanguagePickerAction>) {
        self.store = store
    }
    
    // 2. Sample data for cards
    let hymnals: [Hymnal] = MockStore.cards
    var columns = Array(
        repeating: GridItem(.flexible(), spacing: 15),
        count: 1)
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                HStack {
                    Spacer()
                    CloseButton(action: { viewStore.send(.dismiss) })
                }
                .padding(.all, 16)
                LazyVGrid(columns: columns, alignment: .leading) {
                    ForEach(hymnals) { hymnal in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(hymnal.title)
                                .font(.customCaption)
                                .lineLimit(1)
                                .foregroundColor(.white)
                                .padding(.top, 4)
                            Text(hymnal.subtitle)
                                .lineLimit(1)
                                .font(.customCaption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            HStack {
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(height: 32)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .white]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    }
                }.padding()
                Spacer()
            }
        }
    }
    
    
    
}
