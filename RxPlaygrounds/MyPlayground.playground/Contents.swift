//: Playground - noun: a place where people can play

import UIKit
import RxSwift
import RxCocoa
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true
PlaygroundPage.current.liveView = SearchViewController()

let myFirstObservable = Observable<Int>.create { observer in
    observer.on(.next(1))
    observer.on(.next(2))
    observer.on(.next(3))
    observer.on(.completed)
    return Disposables.create()
}

let subscription = myFirstObservable.subscribe{ event in
    switch event {
    case .next(let element):
        print(element)
    case .error(let error):
        print(error)
    case .completed:
        print("completed")
    }
}

//let subscription = myFirstObservable
//    .map{$0 * 5}
//    .subscribe(onNext: {print("map: \($0)")})

//subscription.dispose()

struct SearchResult {
    let repos: [GithubRepository]
    let totalCount: Int
    init?(response: Any) {
        guard let response = response as? [String:Any],
        let reposDictionaries = response["items"] as? [[String: Any]],
        let count = response["total_count"] as? Int
            else { return nil }
        
        repos = reposDictionaries.flatMap{ GithubRepository(dictionary: $0) }
        totalCount = count
    }
}

struct GithubRepository {
    let name: String
    let startCount: Int
    init(dictionary: [String: Any]) {
        name = dictionary["full_name"] as! String
        startCount = dictionary["stargazers_count"] as! Int
    }
}

func searchRepos(keyword: String) -> Observable<SearchResult?> {
    let endPoint = "https://api.github.com"
    let path     = "/search/repositories"
    let query    = "?q=\(keyword)"
    let url      = URL(string: endPoint + path + query)!
    let request  = URLRequest(url: url)
    return URLSession.shared
        .rx.json(request: request)
        .map{ SearchResult(response: $0) }
}

//let subscription = searchRepos(keyword: "RxSwift")
//    .subscribe(onNext: { print($0!) })

class SearchViewController: UIViewController {
    let searchField = UITextField()
    let totalCountLabel = UILabel()
    let reposLabel = UILabel()
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupSubViews()
        bind()
    }
    
    func setupSubViews() {
        searchField.frame     = CGRect(x: 10, y: 10, width: 300, height: 20)
        totalCountLabel.frame = CGRect(x: 10, y: 40, width: 300, height: 20)
        reposLabel.frame      = CGRect(x: 10, y: 60, width: 300, height: 400)
        
        searchField.borderStyle  = .roundedRect
        reposLabel.numberOfLines = 0
        searchField.keyboardType = .alphabet
        
        view.addSubview(searchField)
        view.addSubview(totalCountLabel)
        view.addSubview(reposLabel)
    }
    
    func bind() {
        let result: Observable<SearchResult?> = searchField.rx.text
            .orEmpty
            .asObservable()
            .skip(1)
            .debounce(0.3, scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .flatMapLatest {
                searchRepos(keyword: $0)
                    .observeOn(MainScheduler.instance)
                    .catchErrorJustReturn(nil)
            }
            .shareReplay(1)
        
        let foundRepos: Observable<String> = result.map {
            let repos = $0?.repos ?? [GithubRepository]()
            return repos.reduce("") {
                $0 + "\($1.name)(\($1.startCount))\n"
            }
        }
        
        let foundCount: Observable<String> = result.map {
            let count = $0?.totalCount
            return "TotalCount: \(count)"
        }
        
        foundRepos
            .bind(to: reposLabel.rx.text)
            .addDisposableTo(disposeBag)
        
        foundCount.startWith("Input Repository Name")
            .bind(to: totalCountLabel.rx.text)
            .addDisposableTo(disposeBag)
    }
}
















