import SwiftUI

struct SizingSettingsTab: View {
    @Bindable var config: SizingConfigStore
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Sizing Parameters")
                        .font(.title2.bold())
                    Spacer()
                    Button("Reset to Defaults") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 4)

                Text("Configure the calculation parameters used by the sizing estimator. Changes take effect immediately.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                tierSection
                baseUserSection
                concurrencySection
                cachingSection
                architectureSection
            }
            .padding(20)
        }
        .confirmationDialog("Reset all sizing parameters to defaults?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) { config.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all sizing parameters to their default values.")
        }
    }

    // MARK: - Tier Thresholds

    private var tierSection: some View {
        GroupBox("Tier Thresholds & Resources") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Per \(config.parameters.baseUserCount) users")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                tierRow(label: "Simple", tier: $config.parameters.simpleTier, color: .green)
                Divider()
                tierRow(label: "Medium", tier: $config.parameters.mediumTier, color: .orange)
                Divider()
                tierRow(label: "Hard", tier: $config.parameters.hardTier, color: .red)
            }
            .padding(.vertical, 4)
        }
    }

    private func tierRow(label: LocalizedStringKey, tier: Binding<SizingTierConfig>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Max Agents").font(.system(size: 12))
                    TextField("", value: tier.maxAgents, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("Max Tools").font(.system(size: 12))
                    TextField("", value: tier.maxTools, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                GridRow {
                    Text("vCPU").font(.system(size: 12))
                    TextField("", value: tier.vCPU, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("RAM (GB)").font(.system(size: 12))
                    TextField("", value: tier.ramGB, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
        }
    }

    // MARK: - Base User Count

    private var baseUserSection: some View {
        GroupBox("Base User Count") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Resource estimates are calculated per this many users, then scaled proportionally if Team Size is set on the project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Users").font(.system(size: 12))
                    TextField("", value: $config.parameters.baseUserCount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Concurrency Multiplier

    private var concurrencySection: some View {
        GroupBox("Concurrency Multiplier") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Inference requests generated per delegating agent. Low = shallow delegation, High = deep delegation chains.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("Low (1–2 layers)").font(.system(size: 12))
                        TextField("", value: $config.parameters.concurrencyMultiplierLow, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    GridRow {
                        Text("High (3+ layers)").font(.system(size: 12))
                        TextField("", value: $config.parameters.concurrencyMultiplierHigh, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Caching Estimates

    private var cachingSection: some View {
        GroupBox("Caching Impact Estimates") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Estimated savings when caching tools are present in the architecture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("Cost savings range (%)").font(.system(size: 12))
                        HStack(spacing: 4) {
                            TextField("", value: $config.parameters.cachingCostSavingsMin, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("–")
                            TextField("", value: $config.parameters.cachingCostSavingsMax, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                    }
                    GridRow {
                        Text("Latency reduction range (%)").font(.system(size: 12))
                        HStack(spacing: 4) {
                            TextField("", value: $config.parameters.cachingLatencyReductionMin, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("–")
                            TextField("", value: $config.parameters.cachingLatencyReductionMax, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Architecture Component Mapping

    private var architectureSection: some View {
        GroupBox("Architecture Component Mapping") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Which tool categories map to each architecture tier. Used to assess the architecture decomposition.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                categoryList(label: "Front Door", categories: $config.parameters.frontDoorCategories)
                Divider()
                categoryList(label: "Agent Runtime", categories: $config.parameters.agentRuntimeCategories)
                Divider()
                categoryList(label: "Inference", categories: $config.parameters.inferenceCategories)
            }
            .padding(.vertical, 4)
        }
    }

    private func categoryList(label: LocalizedStringKey, categories: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))

            let allCategories = ToolCategory.allCases.map(\.rawValue)
            FlowLayout(spacing: 4) {
                ForEach(allCategories, id: \.self) { cat in
                    let isSelected = categories.wrappedValue.contains(cat)
                    Button {
                        if isSelected {
                            categories.wrappedValue.removeAll { $0 == cat }
                        } else {
                            categories.wrappedValue.append(cat)
                        }
                    } label: {
                        Text(ToolCategory(rawValue: cat)?.displayName ?? cat)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            )
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// FlowLayout is defined in AnalysisInspectorView.swift and shared across the app.
