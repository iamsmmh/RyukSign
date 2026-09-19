//
//  VexSignWidgetExtensionBundle.swift
//  VexSignWidgetExtension
//
//  Created by Vex Dev on 10/8/25.
//

import WidgetKit
import SwiftUI

@main
struct VexSignWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        DownloadLiveActivity()
        SigningLiveActivity()
    }
}
