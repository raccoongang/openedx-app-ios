//
//  CourseScreensView.swift
//  Course
//
//  Created by  Stepanok Ivan on 10.10.2022.
//

import SwiftUI
import Core
import Discussion
import Swinject
import Theme
import Kingfisher

public struct CourseContainerView: View {
    
    @ObservedObject
    public var viewModel: CourseContainerViewModel
    @State private var isAnimatingForTap: Bool = false
    public var courseID: String
    private var title: String
    @State private var collapsed: Bool = false
    
    @Namespace private var animationNamespace
    
    public init(
        viewModel: CourseContainerViewModel,
        courseID: String,
        title: String
    ) {
        self.viewModel = viewModel
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await viewModel.getCourseBlocks(courseID: courseID)
                }
                group.addTask {
                    await viewModel.getCourseDeadlineInfo(courseID: courseID, withProgress: false)
                }
            }
        }
        self.courseID = courseID
        self.title = title
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            content
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(false)
//        .navigationTitle(title)
        .onChange(of: viewModel.selection, perform: didSelect)
        .background(Theme.Colors.background)
    }

    @ViewBuilder
    private var content: some View {
        GeometryReader { proxy in
            if let courseStart = viewModel.courseStart {
                if courseStart > Date() {
                    CourseOutlineView(
                        viewModel: viewModel,
                        title: title,
                        courseID: courseID,
                        isVideo: false,
                        selection: $viewModel.selection, 
                        collapsed: $collapsed,
                        dateTabIndex: CourseTab.dates.rawValue
                    )
                } else {
                    ZStack(alignment: .top) {
                        tabs
                        VStack(spacing: 0) {
                            if viewModel.config.uiComponents.courseTopTabBarEnabled {
                                ZStack(alignment: .bottomLeading) {
                                    if let banner = "https://images.nightcafe.studio/jobs/9xlr6jO2wCCiKJGP1SdA/9xlr6jO2wCCiKJGP1SdA--10--AQXOO_6x.jpg?tr=w-1600,c-at_max" // "https://preview.redd.it/ai-panorama-by-thehobolobo-5120x1440-v0-lhecigrg79nb1.jpg?width=1080&crop=smart&auto=webp&s=9f74841a40d985d179a18fa02695ad37e89f24e7" //"https://cdn.pixabay.com/photo/2023/07/02/19/01/ai-generated-8102806_1280.jpg" //viewModel.courseStructure?.media.image.raw
                                        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                                        ScrollView {
                                            KFImage(URL(string: /*viewModel.config.baseURL.absoluteString + */banner))
                                                .onFailureImage(CoreAssets.noCourseImage.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .allowsHitTesting(false)
//                                                .frame(maxWidth: .infinity, maxHeight: collapsed ? 146 : 300)
                                                .clipped()
                                        }
                                        .disabled(true)
//                                        .frame(maxWidth: proxy.size.width, maxHeight: collapsed ? 146 : 300)
                                        .ignoresSafeArea()
                                    }
                                   
                                    VStack(alignment: .leading) {
                                        if collapsed {
                                            VStack {
                                                HStack {
                                                    Button(action: {
                                                        viewModel.router.back(animated: true)
                                                    }, label: {
                                                        Image(systemName: "arrow.left")
                                                            .matchedGeometryEffect(id: "backButton", in: animationNamespace)
                                                    })
                                                    .foregroundStyle(Color.black)
                                                        Text(title)
                                                            .lineLimit(1)
                                                            .foregroundStyle(Color.black)
                                                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                                            .clipped()
                                                            .font(Theme.Fonts.bodyLarge)
                                                }
                                                .padding(.top, 16)
                                                .padding(.horizontal, 24)
                                                topTabBar
                                                    .matchedGeometryEffect(id: "topTabBar", in: animationNamespace)
                                                    .padding(.bottom, 12)
                                            }.background {
                                                VisualEffectView(effect: UIBlurEffect(style: .light))
                                                    .matchedGeometryEffect(id: "blurBg", in: animationNamespace)
                                                    .ignoresSafeArea()
                                            }
                                        } else {
                                            Button(action: {
                                                viewModel.router.back(animated: true)
                                            }, label: {
                                                ZStack {
                                                    VisualEffectView(effect: UIBlurEffect(style: .light))
                                                        .clipShape(Circle())
                                                        .frame(width: 30, height: 30)
                                                    Image(systemName: "arrow.left")
                                                        .matchedGeometryEffect(id: "backButton", in: animationNamespace)
                                                        .padding(.horizontal, 24)
                                                    
                                                }
                                            })
                                            .foregroundStyle(Color.black)
                                            .padding(.top, 55)
                                            Spacer()
                                            VStack {
                                                Text(viewModel.courseStructure?.id ?? "")
                                                    .font(Theme.Fonts.labelLarge)
                                                    .foregroundStyle(Color.black)
                                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                                    .multilineTextAlignment(.leading)
                                                    .padding(.horizontal, 24)
                                                    .padding(.top, 16)
                                                Text(title)
                                                    .lineLimit(3)
                                                    .font(Theme.Fonts.titleLarge)
                                                    .foregroundStyle(Color.black)
                                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                                    .multilineTextAlignment(.leading)
                                                    .padding(.horizontal, 24)
                                                topTabBar
                                                    .matchedGeometryEffect(id: "topTabBar", in: animationNamespace)
                                                    .padding(.bottom, 12)
                                            }.background {
                                                VisualEffectView(effect: UIBlurEffect(style: .light))
                                                    .matchedGeometryEffect(id: "blurBg", in: animationNamespace)
                                                    .ignoresSafeArea()
                                            }
                                        }
                                       
                                    }
                                    
                                }.frame(height: collapsed ? 146 : 300)
                                    .ignoresSafeArea(edges: .top)
                            }
                        }
                        
                    } .ignoresSafeArea(edges: .top)
                }
            }
        }
    }

    private var topTabBar: some View {
        ScrollSlidingTabBar(
            selection: $viewModel.selection,
            tabs: CourseTab.allCases.map { ($0.title, $0.image) }
        ) { newValue in
            isAnimatingForTap = true
            viewModel.selection = newValue
            DispatchQueue.main.asyncAfter(deadline: .now().advanced(by: .milliseconds(300))) {
                isAnimatingForTap = false
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $viewModel.selection) {
            ForEach(CourseTab.allCases) { tab in
                switch tab {
                case .course:
                    CourseOutlineView(
                        viewModel: viewModel,
                        title: title,
                        courseID: courseID,
                        isVideo: false,
                        selection: $viewModel.selection, 
                        collapsed: $collapsed,
                        dateTabIndex: CourseTab.dates.rawValue
                    )
                    .tabItem {
                        tab.image
                        Text(tab.title)
                    }
                    .tag(tab)
                    .accentColor(Theme.Colors.accentColor)
                case .videos:
                    CourseOutlineView(
                        viewModel: viewModel,
                        title: title,
                        courseID: courseID,
                        isVideo: true,
                        selection: $viewModel.selection,
                        collapsed: $collapsed,
                        dateTabIndex: CourseTab.dates.rawValue
                    )
                    .tabItem {
                        tab.image
                        Text(tab.title)
                    }
                    .tag(tab)
                    .accentColor(Theme.Colors.accentColor)
                case .dates:
                    CourseDatesView(
                        courseID: courseID,
                        collapsed: $collapsed,
                        viewModel: Container.shared.resolve(CourseDatesViewModel.self,
                                                            argument: courseID)!
                    )
                    .tabItem {
                        tab.image
                        Text(tab.title)
                    }
                    .tag(tab)
                    .accentColor(Theme.Colors.accentColor)
                case .discussion:
                    DiscussionTopicsView(
                        courseID: courseID,
                        collapsed: $collapsed,
                        viewModel: Container.shared.resolve(DiscussionTopicsViewModel.self,
                                                            argument: title)!,
                        router: Container.shared.resolve(DiscussionRouter.self)!
                    )
                    .tabItem {
                        tab.image
                        Text(tab.title)
                    }
                    .tag(tab)
                    .accentColor(Theme.Colors.accentColor)
                case .handounds:
                    HandoutsView(
                        courseID: courseID,
                        viewModel: Container.shared.resolve(HandoutsViewModel.self, argument: courseID)!
                    )
                    .tabItem {
                        tab.image
                        Text(tab.title)
                    }
                    .tag(tab)
                    .accentColor(Theme.Colors.accentColor)
                }
            }
        }
        .if(viewModel.config.uiComponents.courseTopTabBarEnabled) { view in
            view
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.default, value: viewModel.selection)
        }
        .onFirstAppear {
            Task {
                await viewModel.tryToRefreshCookies()
            }
        }
    }

    private func didSelect(_ selection: Int) {
        CourseTab(rawValue: selection).flatMap {
            viewModel.trackSelectedTab(
                selection: $0,
                courseId: courseID,
                courseName: title
            )
        }
    }
}

#if DEBUG
struct CourseScreensView_Previews: PreviewProvider {
    static var previews: some View {
        CourseContainerView(
            viewModel: CourseContainerViewModel(
                interactor: CourseInteractor.mock,
                authInteractor: AuthInteractor.mock,
                router: CourseRouterMock(),
                analytics: CourseAnalyticsMock(),
                config: ConfigMock(),
                connectivity: Connectivity(),
                manager: DownloadManagerMock(),
                storage: CourseStorageMock(),
                isActive: true,
                courseStart: nil,
                courseEnd: nil,
                enrollmentStart: nil,
                enrollmentEnd: nil
            ),
            courseID: "", title: "Title of Course")
    }
}
#endif

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}
