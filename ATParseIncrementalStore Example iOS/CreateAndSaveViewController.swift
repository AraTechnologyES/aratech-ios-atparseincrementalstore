//
//  CreateAndSaveViewController.swift
//  ATParseIncrementalStore Example iOS
//
//  Created by Nicolás Landa on 3/8/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import UIKit
import CoreData

class CreateAndSaveViewController: UITableViewController {

	var appDelegate: AppDelegate {
		return UIApplication.shared.delegate as! AppDelegate
	}
	
	var context: NSManagedObjectContext {
		return appDelegate.persistentContainer.viewContext
	}
	
	@IBAction func doneButtonAction(_ sender: Any) {
		var managedObject: Category = context.insertObject()
		
		for (key, value) in self.fields where key != nil {
			managedObject.setValue(value, forKey: key!)
		}
		
		context.saveOrLog()
		
		self.dismiss(animated: true, completion: nil)
	}
	
	@IBAction func addFieldButtonAction(_ sender: Any) {
		self.fields.append((nil, nil))
		tableView.beginUpdates()
		tableView.insertRows(at:
			[IndexPath(row: self.fields.count-1, section: 0)], with: .automatic)
		tableView.endUpdates()
	}
	
	// MARK: - Life Cicle
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		tableView.tableFooterView = UIView()
	}
	
	// MARK: - Table View
	
	typealias FieldType = (String?, String?)
	var fields: [FieldType] =
		[("name", "Prueba"),
		 ("icon", Bundle.main.url(forResource: "icon", withExtension: "jpeg")?.path)]
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return fields.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath) as? KeyValueTableViewCell else { fatalError() }
		
		let field = fields[indexPath.row]
		if let key =  field.0 {
			cell.keyText.text = key
		}
		
		if let value = field.1 {
			cell.valueText.text = value
		}
		
		return cell
	}
}

class KeyValueTableViewCell: UITableViewCell {
	
	@IBOutlet weak var keyText: UITextField!
	@IBOutlet weak var valueText: UITextField!
	
}
