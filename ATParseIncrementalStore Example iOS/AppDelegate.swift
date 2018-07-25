//
//  AppDelegate.swift
//  ATParseIncrementalStore Example iOS
//
//  Created by Nicolás Landa on 12/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import os
import UIKit
import Parse
import ATParse
import CoreData
import ATLibrary
import ATParseIncrementalStore

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?


	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		
		self.setUpParse()
		
		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
		// Saves changes in the application's managed object context before the application terminates.
		self.saveContext()
	}

	// MARK: - Core Data stack

	lazy var persistentContainer: NSPersistentContainer = {
	    /*
	     The persistent container for the application. This implementation
	     creates and returns a container, having loaded the store for the
	     application to it. This property is optional since there are legitimate
	     error conditions that could cause the creation of the store to fail.
	    */
		
		let storeType = "ATParseIncrementalStore."+ATParseIncrementalStore.storeType
		NSPersistentStoreCoordinator.registerStoreClass(ATParseIncrementalStore.self,
														forStoreType: storeType)
		
	    let container = NSPersistentContainer(name: "ATParseIncrementalStore_Example_iOS")
		
		let atParseIncrementalStoreDescription = NSPersistentStoreDescription()
		atParseIncrementalStoreDescription.type = storeType
		container.persistentStoreDescriptions = [atParseIncrementalStoreDescription]
		
	    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
	        if let error = error as NSError? {
	            fatalError("Unresolved error \(error), \(error.userInfo)")
			} else {
				os_log("CoreData inicializado correctamente.\t viewContext: %@", log: .default, type: .error, container.viewContext)
			}
	    })
	    return container
	}()

	// MARK: - Core Data Saving support

	func saveContext () {
	    let context = persistentContainer.viewContext
	    if context.hasChanges {
	        do {
	            try context.save()
	        } catch {
	            // Replace this implementation with code to handle the error appropriately.
	            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
	            let nserror = error as NSError
	            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
	        }
	    }
	}
	
	// MARK: - Parse
	
	/// Inicializa la conexión con el servidor Parse
	private func setUpParse() {
		guard let configurationDictionary: Any = self.infoForKey("Parse") else {
			Logger.shared.error("No configuration information found for Parse"); return
		}
		
		do {
			let data = try JSONSerialization.data(withJSONObject: configurationDictionary, options: .prettyPrinted)
			let decoder = JSONDecoder()
			let configuration: ParseClientConfiguration.PlistConfiguration = try decoder.decode(ParseClientConfiguration.PlistConfiguration.self, from: data)
			
			Parse.initialize(with: ParseClientConfiguration { parseConfiguration -> Void in
				parseConfiguration.applicationId = configuration.applicationId
				parseConfiguration.clientKey = configuration.clientKey
				parseConfiguration.server = configuration.server.replacingOccurrences(of: "\\", with: "")
			})
			
			execute(in: .global(qos: .userInteractive)) {
				do {
					try PFConfig.getConfig()
					Logger.shared.info("Parse conectado correctamente")
				} catch {
					Logger.shared.error(error: error)
				}
			}
		} catch let error {
			Logger.shared.error(error.localizedDescription)
		}
	}
	
	private func infoForKey<T>(_ key: String) -> T? {
		return (Bundle.main.infoDictionary?[key] as? T)
	}

}

