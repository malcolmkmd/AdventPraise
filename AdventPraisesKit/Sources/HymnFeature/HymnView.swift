//
//  SwiftUIView.swift
//  
//
//  Created by Malcolm on 6/18/22.
//

import Core
import SwiftUI
import ComposableArchitecture

public struct HymnView: View {
    
    let store: Store<HymnState, HymnAction>
    
    public init(_ store: Store<HymnState, HymnAction>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            ZStack {
                VStack(spacing: 0) {
                    VStack(alignment: .leading) {
                        VStack(alignment: .leading) {
                            Text(viewStore.activeHymn.id)
                                .font(.customTitle)
                            Text(viewStore.activeHymn.title)
                                .font(.customTitle2)
                            Text(viewStore.activeHymn.subtitle)
                                .font(.customBodyItalic)
                                .padding(.bottom, 16)
                        }.padding(.horizontal, 8)
                        Spacer()
                        ScrollView {
                            Text(viewStore.activeHymn.attributedMarkDown())
                                .padding(.horizontal, 8)
                                .padding(.bottom, 16)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(UIColor.systemBackground)
                            .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 10))
                            .shadow(
                                color: Color(uiColor: .systemBackground),
                                radius: 3)
                            .mask(Rectangle().padding(.bottom, -10))
                    )
                    .padding(.bottom, 70)
                }
                .edgesIgnoringSafeArea(.horizontal)
                .zIndex(2)
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { viewStore.send(.didPressBack, animation: .default) }) {
                            Image(.arrowLeft)
                                .font(.customSubheadline)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.bounce())
                        Spacer()
                        Button(action: { }) {
                            Image(systemName: "heart")
                                .font(.customTitle3)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.bounce(scale: 2))
                        Button(action: { }) {
                            Image(systemName: "plus")
                                .font(.customTitle3)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.bounce(scale: 2))
                        Button(action: { }) {
                            Image(.gearshapeFill)
                                .font(.customTitle3)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.bounce(scale: 2))
                        
                    }
                    .padding(.bottom, 8)
                    .padding(.horizontal)
                    .frame(height: 78)
                    .background(Color(uiColor: .systemMint))
                }
                .isHidden(!viewStore.showBottomBar, remove: false)
                .transition(AnyTransition.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .bottom)
                        .combined(with: .opacity)
                ))
                .zIndex(1)
            }
            .edgesIgnoringSafeArea(.horizontal)
            .edgesIgnoringSafeArea(.bottom)
            .onTapGesture {
                viewStore.send(.dismiss)
            }
            .onAppear {
                viewStore.send(.onAppear, animation: .default)
            }
            .transition(.opacity)
        }
    }
    
}

extension Text {
    init(html htmlString: String,
         raw: Bool = false,
         size: CGFloat? = nil,
         fontFamily: String = "-apple-system") {
        let fullHTML: String
        if raw {
            fullHTML = htmlString
        } else {
            var sizeCss = ""
            if let size = size {
                sizeCss = "font-size: \(size)px;"
            }
            fullHTML = """
        <!doctype html>
         <html>
            <head>
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, shrink-to-fit=no\">
              <style>
                body {
                  font-family: \(fontFamily);
                  \(sizeCss)
                }
              </style>
            </head>
            <body>
              \(htmlString)
            </body>
          </html>
        """
        }
        let attributedString: NSAttributedString
        if let data = fullHTML.data(using: .unicode),
           let attrString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil) {
            attributedString = attrString
        } else {
            attributedString = NSAttributedString()
        }
        
        self.init(attributedString) // uses the NSAttributedString initializer
    }
}

extension Text {
    init(_ attributedString: NSAttributedString) {
        self.init("")
        attributedString.enumerateAttributes(
            in: NSRange(
                location: 0,
                length: attributedString.length),
            options: []) { (attrs, range, _) in
                let string = attributedString.attributedSubstring(
                    from: range).string
                var text = Text(string)
                
                // then, read applicable attributes and apply them to the Text
                
                text = text.font(.customBody)
                
                if let color = attrs[.foregroundColor] as? UIColor {
                    text = text.foregroundColor(Color(color))
                }
                
                if let kern = attrs[.kern] as? CGFloat {
                    text = text.kerning(kern)
                }
                
                if let tracking = attrs[.tracking] as? CGFloat {
                    text = text.tracking(tracking)
                }
                
                // append the newly styled subtext to the rest of the text
                self = self + text
            }
    }
}
