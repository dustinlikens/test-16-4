//
//  UniversalSearchViewController.swift
//  Flagship
//
//  Created by Likens, Dustin on 5/30/22.
//  Copyright © 2022 Steve Lundgren. All rights reserved.
//

import UIKit
internal import RealmSwift
import Meridian
import SafariServices
internal import FlagshipData

class UniversalSearchViewController : UIViewController, UITextFieldDelegate {

    //MARK: Properties
    
    var searchResults: Array<UniversalSearchResult> = []
    var searchBarDistance: CGFloat?
    let realm = try! Realm(configuration: Realm.Configuration(schemaVersion: SCHEMA_VERSION))
    var task: URLSessionDataTask?
    var loadingIndicator = UIActivityIndicatorView()
    
    let searchVersion = UserDefaults.standard.bool(forKey: openSearchStr) ? "2" : "1"
    
    //MARK: Outlets
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchBarTop: NSLayoutConstraint!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyStateView: UIStackView!
    
    //MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        styleSearchBar()
        searchBar.delegate = self
        searchBar.becomeFirstResponder()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.keyboardDismissMode = .onDrag
        tableView.tableFooterView = UIView()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(endSearch))
        
        loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        loadingIndicator.style = UIActivityIndicatorView.Style.large
        loadingIndicator.color = UIColor(named: "primary2")
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
        
        MeridianDataProvider.shared.preload()
        
        searchBar.searchTextField.delegate = self
        
        recordEvent(type: .screen, properties: [.name: "Search"])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        searchBarTop.constant = searchBarDistance ?? searchBarTop.constant
    }
    
    // MARK: Private
    
    private func downloadThumbnail(for imageName: String, complete:@escaping () -> Void) {
            let imageUrl = String.assetUrl(imageName: imageName, descriptor: "thumbnail")
            if let url = URL(string: imageUrl) {
                URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
                    if (error != nil) { print("Error downloading thumbnail:", error!) }
                    if let data = data, let responseType = response?.mimeType {
                        if responseType.contains("image"), let _ = UIImage(data: data) {
                            let writePath = documentsPath.appendingPathComponent("thumbnail" + imageName)
                            NSData(data: data).write(toFile: writePath, atomically: true)
                            complete()
                        }
                    }
                }).resume()
            }
        }
    
    private func search(for text: String) {
        task?.cancel()
        guard let query = text.lowercased().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return }
        
        let lang = Locale.current.languageCode == "es" ? "es" : "en"
        let queryUrl = "\(Settings.shared.searchUrl)?q=\(query)&language=\(lang)&version=\(searchVersion)"
        let requestUrl = URL(string: queryUrl)!
        task = URLSession.shared.dataTask(with: requestUrl) {(data, response, error) in
            guard let data = data else { return }
            DispatchQueue.main.async { [self] in
                self.loadResults(data: data)
                loadingIndicator.stopAnimating()
            }
        }
        task?.resume()
        if text.count > 2 {
            recordEvent(type: .search, properties: [.name: text, .currentScreen: "Search"])
        }
    }
    
    private func styleSearchBar() {
        searchBar.returnKeyType = .search
        searchBar.setPositionAdjustment(UIOffset(horizontal: -5, vertical: 0), for: .clear)
        searchBar.setHeight(height: isIPad ? 32 : 44)
        if let textfield = searchBar.value(forKey: "searchField") as? UITextField {
            textfield.textColor = UIColor.blue

            if let backgroundview = textfield.subviews.first {
                backgroundview.backgroundColor = UIColor.clear
                backgroundview.layer.cornerRadius = 10;
                backgroundview.clipsToBounds = true;
            }
        }
        if let borderColor = UIColor(named: "border") {
            searchBar.setStyleColor(borderColor: borderColor.cgColor)
        }
        if let image = UIImage(named: "magnifyingGlassBlue") {
            print("magnifyingGlassBlue")
            let icon = UIImage.scaleToSize(image: image, scaledToSize: CGSize(width: 19, height: 19))
            searchBar.setImage(icon, for: .search, state: .normal)
            searchBar.setPositionAdjustment(UIOffset(horizontal: 5, vertical: 0), for: .search)
        }
    }
    
    private func loadResults(data: Data) {
        do {
            if let results = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [Dictionary<String,Any>] {
                self.searchResults.removeAll()
                if results.count == 0 {
                    emptyStateView.isHidden = false
                }
                for (index, result) in results.enumerated() {
                    var item = UniversalSearchResult()
                    item.id = result["id"] as? String
                    if let title = result["title"] as? String {
                        item.title = title
                    } else if let name = result["name"] as? String {
                        item.title = name
                    }
                    item.dest = result["dest"] as? String
                    item.entity_type = result[getKey(for: .entityType)] as? String
                    item.placemark_type = result["type"] as? String
                    item.category = result["category"] as? String
                    item.phone = result["phone"] as? String
                    item.parent = result["parent"] as? String
                    item.parent_name = result[getKey(for: .parentName)] as? String
                    item.parent_short_name = result[getKey(for: .parentShortName)] as? String
                    item.url = result["url"] as? String
                    item.app_key = result[getKey(for: .appKey)] as? String
                    item.floor = result["floor"] as? String
                    if let map_key = item.id?.components(separatedBy: "_")[0] as? String {
                        item.map_key = map_key
                    }
                    if let imageName = result["image"] as? String {
                        item.imageName = imageName
                        let path = documentsPath.appendingPathComponent("thumbnail" + imageName)
                        if let image = UIImage(contentsOfFile: path) {
                            item.image = image
                        } else {
                            downloadThumbnail(for: imageName) {
                                DispatchQueue.main.async {
                                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                                }
                            }
                        }
                    }
                    if let multi_location = result[getKey(for: .multiLocation)] as? [Dictionary<String, Any?>] {
                        item.multi_location = multi_location
                    }
                    self.searchResults.append(item)
                }
            }
            tableView.reloadData()
        } catch {
            print("Failed parsing universal search JSON: ", error)
        }
    }
    
    @objc func endSearch(sender: UIBarButtonItem?) {
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.fade
        self.navigationController?.view.layer.add(transition, forKey: nil)
        navigationController?.popViewController(animated: false)
    }
    
    private func presentLocationPicker(for locations: [Dictionary<String, Any?>], action: @escaping (_ location: Dictionary<String, Any?>) -> Void) {
        let alert = UIAlertController(title: selectLocationLabel, message: nil, preferredStyle: .actionSheet)
        
        for location in locations {
            if let parent_name = location[getKey(for: .parentName)] as? String {
                alert.addAction(UIAlertAction(title: NSLocalizedString(parent_name, comment: "Select location"), style: .default, handler: { _ in
                    action(location)
                }))
            }
        }
        
        alert.addAction(UIAlertAction(title: cancelButtonStr, style: .cancel, handler: nil))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    private func selectAmenity(searchResult: UniversalSearchResult) {
        if let multi_location = searchResult.multi_location {
            presentLocationPicker(for: multi_location) { location in
                if let id = location["id"] as? String {
                    Task {
                        let _ = await FlagshipData.shared.load(Amenity.self, id: id).result
                        self.openAmenity(with: id)
                    }
                }
            }
        } else if let id = searchResult.id {
            Task {
                let _ = await FlagshipData.shared.load(Amenity.self, id: id).result
                openAmenity(with: id)
            }
        }
    }
    
    private func selectPlacemark(searchResult: UniversalSearchResult) {
        guard let app_key = searchResult.app_key,
              let map_id = searchResult.map_key,
              let realm = try? FlagshipData.realm()
        else { return }
        if let multi_location = searchResult.multi_location {
            // Multiple facilities
            if multi_location.count > 1 {
                presentLocationPicker(for: multi_location) { location in
                    guard let app_key = location[getKey(for: .appKey)] as? String,
                          let facility = realm.object(ofType: Facility.self, forPrimaryKey: location["parent"]),
                          let id = location["id"] as? String,
                          let title = searchResult.title
                    else { return }
                    MeridianDataProvider.shared.search(for: title, at: facility) { (results, err) in
                        let mapIdentifier = id.components(separatedBy: "_")[0]
                        let mapKey = MREditorKey(forMap: mapIdentifier, app: app_key)
                        let subtitledPlacemarks = results.map( {SubtitledPlacemark(from: $0)} )
                        self.open(placemarks: subtitledPlacemarks, on: mapKey)
                    }
                }
            // Single facility, multiple placemarks
            } else if let title = searchResult.title, let facility = realm.object(ofType: Facility.self, forPrimaryKey: searchResult.parent) {
                MeridianDataProvider.shared.search(for: title, at: facility) { (results, err) in
                    let mapKey = MREditorKey(forMap: map_id, app: app_key)
                    let subtitledPlacemarks = results.map({ SubtitledPlacemark(from: $0) })
                    self.open(placemarks: subtitledPlacemarks, on: mapKey)
                }
            }
        // Single facility, single placemark
        } else if let placemarkId = searchResult.id {
            let mapKey = MREditorKey(forMap: map_id, app: app_key)
            let placemark = MRPlacemark()
            placemark.key = MREditorKey(forPlacemark: placemarkId, map: mapKey)
            open(placemarks: [placemark], on: mapKey)
        }
    }
    
    private func open(placemarks: [MRPlacemark], on map: MREditorKey) {
        guard let mapController = SCMapViewController(editorKey: map) else { return }
        navigationController?.pushViewController(mapController, animated: false)
        if placemarks.count > 1 {
            mapController.showBottomSheet(with: placemarks)
        } else if let placemark = placemarks.first {
            mapController.focus(on: placemark)
        }
    }
    
    private func openAmenity(with id: String) {
        guard let amenity = (try? FlagshipData.realm())?.object(ofType: Amenity.self, forPrimaryKey: id),
              let dest = amenity.dest
        else { return }
        switch (dest) {
        case "amenityDetail":
            let destVC = storyboard!.instantiateViewController(withIdentifier: "AmenityViewController") as! AmenityViewController
            destVC.amenity = amenity
            super.navigationController?.pushViewController(destVC, animated: true)
        case "amenityTableView":
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let destVC = storyboard.instantiateViewController(withIdentifier: "AmenityTableViewController") as! AmenityTableViewController
            destVC.category = amenity.title
            destVC.nestedAmenities = Array(amenity.nestedAmenities)
            super.navigationController?.pushViewController(destVC, animated: true)
        case "amenityMap":
            let destVC = self.storyboard!.instantiateViewController(withIdentifier: "NearbyMapViewController") as! NearbyMapViewController
            destVC.amenity = amenity
            super.navigationController?.pushViewController(destVC, animated: true)
        default:
            return
        }
    }
    
    private func openSchedulingNumber(searchResult: UniversalSearchResult) {
        if let phoneNumber = searchResult.phone, let url = URL(string: "tel://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openUrl(searchResult: UniversalSearchResult) {
        guard let resultUrl = searchResult.url, let url = URL(string: resultUrl) else { return }
        let vc = SFSafariViewController(url: url, configuration: SFSafariViewController.Configuration())
        present(vc, animated: true)
    }
    
    private func openUrgentCare() {
        guard let urgentCareViewController = UrgentCareHostingController() else { return }
        navigationController?.pushViewController(urgentCareViewController, animated: true)
    }
    
    private func openFacility() {
        tabBarController?.selectedIndex = Screen.Locations.rawValue
    }
    
    private func recordAbortedSearch() {
        guard let searchText = searchBar.text else { return }
        recordEvent(type: .searchAborted, properties: [.searchText: searchText])
    }
    
}

//MARK: SearchBar Delegate

extension UniversalSearchViewController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        guard let selectedColor = UIColor(named: "primary2")?.cgColor else { return }
        searchBar.setStyleColor(borderColor: selectedColor)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if (searchText.count > 0) {
            if (searchResults.count == 0) {
                loadingIndicator.startAnimating()
                emptyStateView.isHidden = true
            }
            search(for: searchText)
            searchBar.setShowsCancelButton(true, animated: true)
            if let cancelButton = searchBar.value(forKey: "cancelButton") as? UIButton {
                cancelButton.setTitleColor(UIColor(named: "gray3"), for: .normal)
                cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: isIPad ? 17 : 14)
            }
        } else {
            task?.cancel()
            searchResults.removeAll()
            tableView.reloadData()
            searchBar.setShowsCancelButton(false, animated: true)
            loadingIndicator.stopAnimating()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        recordAbortedSearch()
        endSearch(sender: nil)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        recordAbortedSearch()
        return true
    }
    
}

//MARK: TableView Delegate

extension UniversalSearchViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalSearchTableViewCell.identifier, for: indexPath) as! UniversalSearchTableViewCell
        let searchResult = searchResults[indexPath.item]
        cell.configure(with: searchResult)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        searchBar.resignFirstResponder()
        
        let result = searchResults[indexPath.item], dest = result.dest, type = result.entity_type?.lowercased()
        if dest == "amenityDetail" || dest == "amenityMap" || dest == "amenityTableView" {
            selectAmenity(searchResult: result)
        } else if type == "placemark" {
            selectPlacemark(searchResult: result)
        } else if ["scheduling_number", "scheduling-number"].contains(type) {
            openSchedulingNumber(searchResult: result)
        } else if ["url", "urls"].contains(type) {
            openUrl(searchResult: result)
        } else if ["urgent_care", "urgent-care"].contains(type) {
            openUrgentCare()
        } else if type == "facility" {
            openFacility()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        recordEvent(type: .searchResult, properties: [.name: result.title ?? "", .id: result.id ?? "", .entityType: result.entity_type ?? "", .searchText: searchBar.text ?? ""])
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
    
}
