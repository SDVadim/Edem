import SwiftUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Section("Профиль") {
                TextField("Имя", text: $viewModel.userName)
                    .textContentType(.givenName)
                TextField("E-mail для чеков", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Статистика") {
                LabeledContent("Поездок", value: "\(viewModel.stats.tripsCount)")
                LabeledContent("Минут в пути", value: "\(viewModel.stats.totalMinutes)")
                LabeledContent("Потрачено", value: Formatters.rubles(viewModel.stats.totalSpent))
                LabeledContent("Фото в актах осмотра", value: "\(viewModel.stats.inspectionPhotos)")
            }

            Section {
                Toggle("Нет связи с машиной", isOn: $viewModel.simulateNoConnection)
            } header: {
                Text("Демо-режим")
            } footer: {
                Text("Имитирует подземный паркинг: команда закрытия не доходит до машины. "
                    + "Так можно пройти ветку ошибки из стори-фрейма — повтор и закрытие через оператора.")
            }

            Section("О приложении") {
                LabeledContent("Данные о машинах", value: "dummyjson.com")
                LabeledContent("Хранилище", value: "SwiftData")
            }
        }
        .navigationTitle("Профиль")
        .onAppear { viewModel.reloadStats() }
    }
}
