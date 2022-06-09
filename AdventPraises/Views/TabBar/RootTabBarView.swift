//
//  MainTabBarView.swift
//  AdventPraises
//
//  Created by Malcolm on 6/7/22.
//

import SwiftUI

struct RootTabBarView: View {
    
    @State var currentTab: Tab = .number
    
    init() {
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentTab) {
                NumberView()
                    .tag(Tab.number)
                Text("Hymns")
                    .applyBackgroundColor()
                    .tag(Tab.hymns)
                Text("More")
                    .applyBackgroundColor()
                    .tag(Tab.more)
            }
            AnimatedTabView(currentTab: $currentTab)
        }
    }
}

extension View {
    func applyBackgroundColor() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color(.systemBackground)
            }
            .ignoresSafeArea()
    }
}

struct MainTabBarView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabBarView().environmentObject(Store(initialState: AppState(), reducer: appReducer(state:action:)))
    }
}
