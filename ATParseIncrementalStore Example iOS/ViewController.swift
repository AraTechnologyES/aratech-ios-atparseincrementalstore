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
import ATParseIncrementalStore

class ViewController: UIViewController {

	var appDelegate: AppDelegate {
		return UIApplication.shared.delegate as! AppDelegate
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		NotificationCenter.default.addObserver(self,
											   selector: #selector(self.handleManagedObjectUpdates(_:)),
											   name: NSNotification.Name.NSManagedObjectContextObjectsDidChange,
											   object: nil)
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		let context = appDelegate.persistentContainer.viewContext
		
		let predicate = NSPredicate(format: "name = 'Default'")
		let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Project")
		fetchRequest.predicate = predicate
		fetchRequest.fetchLimit = 1
		
		do {
			let results = try context.fetch(fetchRequest)
			print("Cacheado: \n\(String(describing: results.first) ?? "ninguno")")
		} catch {
			Logger.shared.error(error: error)
		}
	}
	
	// MARK: - Notification handlers
	
	@objc func handleManagedObjectUpdates(_ notification: Notification) {
		guard let userInfo = notification.userInfo else { return }
		
		if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
			
			print("Actualizados: \n\(updates.reduce("", { $0+"\t\($1)" }))")
		}
	}
}

