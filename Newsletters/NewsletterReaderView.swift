import SwiftUI
import FirebaseFirestore

struct NewsletterReaderView: View {
    let newsletter: NewsletterMetadata  // Metadata passed from previous view, with its document ID available in newsletter.id

    @StateObject private var dataVM = NewsletterDataViewModel()
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // Custom top bar
            HStack {
                // Back arrow on the far left
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .padding(.leading, 8)

                // Center: Sender and subject
                VStack(spacing: 2) {
                    Text(newsletter.vendorName)
                        .font(.headline)
                    Text(newsletter.subject)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)

                // Right: Date in two lines (month/day on first line, year on second)
                VStack(spacing: 0) {
                    let (monthDay, year) = formattedDateComponents(newsletter.newsletterDate)
                    Text(monthDay)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(year)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 4)  // minimal right padding
            }
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // Content area
            ZStack {
                if dataVM.isLoading {
                    ProgressView("Loading...")
                        .padding()
                } else {
                    HTMLWebView(htmlContent: dataVM.content)
                }
            }
        }
        .navigationBarHidden(true) // Hide the default navigation bar.
        .onAppear {
            DispatchQueue.main.async {
                // Use newsletter.id as the doc ID for querying the data.
                dataVM.fetchData(newsletterId: newsletter.id ?? "")
            }
        }
    }
    
    /// Splits the date into a month/day string and a year string.
    private func formattedDateComponents(_ date: Date) -> (String, String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d,"  // e.g. "Apr 3,"
        let monthDay = formatter.string(from: date)
        formatter.dateFormat = "yyyy"     // e.g. "2025"
        let year = formatter.string(from: date)
        return (monthDay, year)
    }
}
