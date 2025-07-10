import SwiftUI

struct InfoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("GeoCam")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("GeoCam is a study project developed by the Institute for Geoinformatics at the University of Münster.")
                    
                    Text("In today's digital landscape, disinformation and manipulated media - especially photos and videos - are a growing problem. It’s becoming increasingly difficult to trust the authenticity of visual content.")
                    
                    Text("GeoCam addresses this challenge by allowing users to capture cryptographically signed and geotagged images. These 'geo-signed' images include proof of when and where they were taken, offering a higher level of trust and integrity.")
                    
                    Text("The app is intended as a technical demonstration: users can capture geo-signed images, share them with others, and later validate their authenticity using GeoCam’s verification tools.")
                    
                    Text("This makes GeoCam a potential foundation for combating visual disinformation in journalism, science, and civic documentation.")
                    
                    Divider()
                    
                    Text("For more information about the app, please visit:")
                        .padding(.top)
                    
                    Link("GitHub", destination: URL(string: "https://github.com/SP3DAG")!)
                        .foregroundColor(.blue)
                        .underline()
                }
                .padding()
            }
            .navigationTitle("About GeoCam")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
