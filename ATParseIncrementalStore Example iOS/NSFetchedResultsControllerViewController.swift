//
//  NSFetchedResultsControllerViewController.swift
//  ATParseIncrementalStore Example iOS
//
//  Created by Nicolás Landa on 26/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import os
import UIKit
import CoreData
import ATCoreData

extension Category: ATManaged { }

class NSFetchedResultsControllerViewController: UITableViewController, NSFetchedResultsControllerDelegate {

	var appDelegate: AppDelegate {
		return UIApplication.shared.delegate as! AppDelegate
	}
	
	var context: NSManagedObjectContext {
		return appDelegate.persistentContainer.viewContext
	}
	
	lazy var fetchedResultsController: NSFetchedResultsController<Category> = {
		let fetchedResultsController = NSFetchedResultsController<Category>(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
		fetchedResultsController.delegate = self
		
		
		return fetchedResultsController
	}()
	
	var request: NSFetchRequest<Category> {
		let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
		fetchRequest.fetchLimit = 500
		fetchRequest.fetchBatchSize = 20
		return fetchRequest
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		self.navigationItem.title = "NSFetchedResultsController"
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		do {
			try self.fetchedResultsController.performFetch()
			self.tableView.reloadData()
		} catch {
			os_log("Error al realizar la búsqueda: %@",
				   log: .default, type: .error, error.localizedDescription)
		}
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.fetchedResultsController.fetchedObjects?.count ?? 0
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
		let object = self.fetchedResultsController.fetchedObjects?[indexPath.row]
		cell.textLabel?.text = object?.objectID.uriRepresentation().lastPathComponent ?? "-1"
		cell.detailTextLabel?.text = object?.icon
		return cell
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
}
