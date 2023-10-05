//
//  PhotoViewController.swift
//  Virtual Tourist
//
//  Created by Monty Harper on 10/4/23.
//

import Foundation
import UIKit

class PhotoViewController: UIViewController {
    
    var photo = UIImage(named:"shrug")
    
    @IBOutlet weak var photoView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        photoView.image = photo
    }
    
}
