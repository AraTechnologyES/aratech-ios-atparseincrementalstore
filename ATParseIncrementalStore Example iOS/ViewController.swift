//
//  ViewController.swift
//  ATParseIncrementalStore Example iOS
//
//  Created by Nicolás Landa on 12/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import UIKit
import Parse
import ATParse
import CoreData
import ATLibrary
import ATCoreData
import ATParseIncrementalStore

extension Experiment: ATManaged { }
extension User: ATManaged { }
extension Band: ATManaged { }
extension Sample: ATManaged { }

class ViewController: UITableViewController, NSFetchedResultsControllerDelegate {

	var appDelegate: AppDelegate {
		return UIApplication.shared.delegate as! AppDelegate
	}
	
	var context: NSManagedObjectContext {
		return appDelegate.persistentContainer.viewContext
	}
	
	var fetchedResultsController: NSFetchedResultsController<Band>?
	
	let pageSize = 20
	
	func request(page: Int) -> NSFetchRequest<Experiment> {
		let fetchRequest: NSFetchRequest<Experiment> = Experiment.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Band.opticalDensity, ascending: true)]
		fetchRequest.fetchOffset = pageSize*page
		fetchRequest.fetchLimit = pageSize
		return fetchRequest
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		NotificationCenter.default.addObserver(self,
											   selector: #selector(self.handleManagedObjectUpdates(_:)),
											   name: NSNotification.Name.NSManagedObjectContextObjectsDidChange,
											   object: nil)
		
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(handleRefreshControl(_:)), for: .valueChanged)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
	
		tableView.tableFooterView = refreshControl
//		loadNextPage()
//
//		NotificationCenter.default.addObserver(self,
//											   selector: #selector(handleContextDidFetchNewValuesForObject(_:)),
//											   name: .ATIncrementalStoreContextDidFetchNewValuesForObject, object: nil)

		let request: NSFetchRequest<Band> = Band.fetchRequest()
		request.fetchLimit = 1
		request.predicate = NSPredicate(format: "objectId = %@", "gxd9j8KcS7")
		
		let results = try! context.fetch(request)
		results.first?.opticalDensity += 1
		
		context.saveOrLog()
	}
	
	@objc func handleContextDidFetchNewValuesForObject(_ sender: Any) {
		guard let notification = sender as? Notification else { return }
		
		if let updated = self.bands.first(where: { $0.creator?.objectID == notification.userInfo?["objectID"] as? NSManagedObjectID }) {

			if let indexPath = self.bands.index(of: updated).map({ IndexPath(row: $0, section: 0) }) {
				DispatchQueue.main.async {
					self.tableView.reloadRows(at: [indexPath], with: .automatic)
				}
			}
		}
	}
	
	@objc func handleRefreshControl(_ sender: Any) {
		try? fetchedResultsController?.performFetch()
		execute(in: .main, delay: DispatchTime.now()+2) {
			self.refreshControl?.endRefreshing()
		}
	}
	
	var loading = false
	var isLastPage = false
	
	func loadNextPage() {
		guard !loading, !isLastPage else { return }
		
		refreshControl?.beginRefreshing()
		
		let nextPage: Int = self.bands.count / pageSize
		let asyncRequest = NSAsynchronousFetchRequest(fetchRequest: request(page: nextPage)) { (result) in
			guard let bands = result.finalResult else { return }
			
			self.isLastPage = bands.count < self.pageSize
			
			self.bands.append(contentsOf: bands)
			
			let objectsBeforeUpdate = self.tableView.numberOfRows(inSection: 0)
			let objectsAfterUpdate = objectsBeforeUpdate+bands.count-1
			
			guard objectsAfterUpdate > objectsBeforeUpdate else { return }
			
			let indexPaths = (objectsBeforeUpdate...objectsAfterUpdate).map({ IndexPath(row: $0, section: 0) })
			
			DispatchQueue.main.async {
				self.tableView.beginUpdates()
				self.tableView.insertRows(at: indexPaths, with: .automatic)
				self.tableView.endUpdates()
				
				self.refreshControl?.endRefreshing()
			}
			
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+3, execute: {
				self.tableView.reloadData()
			})
			
			self.loading = false
		}
		
		loading = true
		try? context.execute(asyncRequest)
	}
	
	// MARK: - Table
	
	var bands: [Experiment] = []
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.bands.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
		cell.textLabel?.text = "\(self.bands[indexPath.row].creator?.username)"
		return cell
	}
	
	override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		if indexPath.row == self.bands.count - 1 {
			loadNextPage()
		}
	}
	
	// MARK: - Delegate
	
	func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		self.tableView.beginUpdates()
	}
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		self.tableView.endUpdates()
	}
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
					didChange anObject: Any, at indexPath: IndexPath?,
					for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		
		switch type {
		case .insert:
			guard let indexPath = newIndexPath else { return }
			self.tableView.insertRows(at: [indexPath], with: .automatic)
		case .delete:
			guard let indexPath = indexPath else { return }
			self.tableView.deleteRows(at: [indexPath], with: .automatic)
		case .update:
			guard let indexPath = indexPath else { return }
			self.tableView.reloadRows(at: [indexPath], with: .automatic)
		case .move:
			guard let indexPath = indexPath, let newIndexPath = newIndexPath else { return }
			self.tableView.moveRow(at: indexPath, to: newIndexPath)
		}
	}
	
	// MARK: - Notification handlers
	
	@objc func handleManagedObjectUpdates(_ notification: Notification) {
		guard let userInfo = notification.userInfo else { return }
		
		if let refreshedObjects = userInfo[NSRefreshedObjectsKey] as? Set<NSManagedObject> {
			
			for refreshed in refreshedObjects {
				if let refreshedObjectIndex = self.bands.index(where: { $0.creator?.objectID == refreshed.objectID }) {
					
				}
			}
		}
	}
}

