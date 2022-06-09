//
//  AnimatedTabView.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI

struct AnimatedTabView: View {
    
    @Binding var currentTab: Tab
    
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 60) {
                ForEach(Tab.allCases, id: \.rawValue) { tab in
                    Button(action: {
                        withAnimation(.easeIn(duration: 0.3)) {
                            currentTab = tab
                        }
                    }, label: {
                        VStack {
                            if currentTab == tab {
                                Text(tab.title)
                                    .transition(.opacity)
                            } else {
                                Image(tab.symbol.standard)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 40, maxHeight: 32)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .foregroundColor(currentTab == tab ? Color(.purple) : Color(.gray))
                        .frame(width: 80)
                    })
                }
            }.frame(maxWidth: .infinity)
        }
        .frame(height: 60)
        .padding([.top])
    }
}

#if DEBUG
struct AnimatedTabView_PreviewContainer: View {
    
    @State var currentTab: Tab = .number
    
    var body: some View {
        AnimatedTabView(currentTab: $currentTab)
    }
}

struct AnimatedTabView_Previews: PreviewProvider {
    
    static var previews: some View {
        AnimatedTabView_PreviewContainer()
    }
    
}
#endif

