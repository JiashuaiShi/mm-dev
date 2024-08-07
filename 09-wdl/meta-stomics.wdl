version development

workflow combined_metagenomic_workflow {
    input {
        # KneadData inputs
        Array[File] input_files_r1
        Array[File] input_files_r2
        Directory kneaddata_db
        Int kneaddata_threads

        # Kraken2 and downstream analysis inputs
        Directory kraken2_db
        Int kraken_threads
        Float confidence
        Int min_base_quality
        Int min_hit_groups
        Array[String] output_tsv_names
        Array[String] report_txt_names
        Array[String] krona_output_html_names
        File qiime2_sample_metadata
        Int qiime2_min_frequency = 1
        Int qiime2_min_samples = 2
        Int qiime2_sampling_depth = 10
        File taxonomy_convert_script
    }

    # Step 1: Run KneadData on input files
    scatter (i in range(length(input_files_r1))) {
        call KneadDataTask {
            input:
                input_file_r1 = input_files_r1[i],
                input_file_r2 = input_files_r2[i],
                kneaddata_db = kneaddata_db,
                threads = kneaddata_threads
        }
    }

    # Step 2: Run Kraken2 on KneadData output
    scatter (i in range(length(KneadDataTask.output_paired_1))) {
        call Kraken2Task {
            input:
                input_file_r1 = KneadDataTask.output_paired_1[i],
                input_file_r2 = KneadDataTask.output_paired_2[i],
                kraken2_db = kraken2_db,
                threads = kraken_threads,
                confidence = confidence,
                min_base_quality = min_base_quality,
                min_hit_groups = min_hit_groups,
                output_tsv_name = output_tsv_names[i],
                report_txt_name = report_txt_names[i]
        }
    }

    # Step 3: Merge Kraken2 TSV outputs
    call MergeTSVTask {
        input:
            input_files = Kraken2Task.output_tsv_file
    }

    # Step 4: Generate BIOM file from Kraken2 reports
    call kraken_biom {
        input:
            input_files = Kraken2Task.report_txt_file,
            output_filename = "kraken_biom_output.biom"
    }

    # Step 5: Generate Krona visualizations
    scatter (idx in range(length(Kraken2Task.report_txt_file))) {
        call krona {
            input:
                input_file = Kraken2Task.report_txt_file[idx],
                output_filename = krona_output_html_names[idx]
        }
    }

    # Step 6: QIIME2 analysis
    call ImportFeatureTable {
        input:
            input_biom = kraken_biom.output_biom
    }

    call ConvertKraken2Tsv {
        input:
            qiime2_merged_taxonomy_tsv = MergeTSVTask.merged_tsv,
            taxonomy_convert_script = taxonomy_convert_script
    }

    call ImportTaxonomy {
        input:
            input_tsv = ConvertKraken2Tsv.merge_converted_taxonomy
    }

    call FilterLowAbundanceFeatures {
        input:
            input_table = ImportFeatureTable.output_qza,
            qiime2_min_frequency = qiime2_min_frequency
    }

    call FilterRareFeatures {
        input:
            input_table = FilterLowAbundanceFeatures.filtered_table,
            qiime2_min_samples = qiime2_min_samples
    }

    call RarefyTable {
        input:
            input_table = FilterRareFeatures.filtered_table,
            qiime2_sampling_depth = qiime2_sampling_depth
    }

    call CalculateAlphaDiversity {
        input:
            input_table = RarefyTable.rarefied_table
    }

    call ExportAlphaDiversity {
        input:
            input_qza = CalculateAlphaDiversity.alpha_diversity
    }

    call CalculateBetaDiversity {
        input:
            input_table = RarefyTable.rarefied_table
    }

    call PerformPCoA {
        input:
            distance_matrix = CalculateBetaDiversity.distance_matrix
    }

    call AddPseudocount {
        input:
            input_table = RarefyTable.rarefied_table
    }

    output {
        Array[File] kneaddata_paired_1 = KneadDataTask.output_paired_1
        Array[File] kneaddata_paired_2 = KneadDataTask.output_paired_2
        File merged_tsv = MergeTSVTask.merged_tsv
        Array[File] kraken2_report_txt = Kraken2Task.report_txt_file
        File output_biom = kraken_biom.output_biom
        Array[File] krona_html_reports = krona.output_html
        File filtered_table = FilterRareFeatures.filtered_table
        File rarefied_table = RarefyTable.rarefied_table
        File distance_matrix = CalculateBetaDiversity.distance_matrix
        File pcoa = PerformPCoA.pcoa
        File comp_table = AddPseudocount.comp_table
        File shannon_diversity = ExportAlphaDiversity.exported_diversity
    }
}

# KneadData task to preprocess raw sequencing data

task KneadDataTask {
    input {
        File input_file_r1
        File input_file_r2
        Directory kneaddata_db
        Int threads
    }

    command {
        kneaddata \
        --input1 ${input_file_r1} \
        --input2 ${input_file_r2} \
        --reference-db ${kneaddata_db} \
        --output kneaddata_out \
        --threads ${threads} \
        --remove-intermediate-output
    }

    output {
        File output_paired_1 = "kneaddata_out/${basename(input_file_r1, ".fastq")}_kneaddata_paired_1.fastq"
        File output_paired_2 = "kneaddata_out/${basename(input_file_r1, ".fastq")}_kneaddata_paired_2.fastq"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_61de51c7c6c94844b47e7ea1d7b8830e_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}


# Kraken2 task for taxonomic classification

task Kraken2Task {
    input {
        File input_file_r1
        File input_file_r2
        Directory kraken2_db
        Int threads
        Float confidence
        Int min_base_quality
        Int min_hit_groups
        String output_tsv_name
        String report_txt_name
    }

    command {
        kraken2 --db ${kraken2_db} \
        --threads ${threads} \
        --confidence ${confidence} \
        --minimum-base-quality ${min_base_quality} \
        --minimum-hit-groups ${min_hit_groups} \
        --output ${output_tsv_name} \
        --report ${report_txt_name} \
        --paired ${input_file_r1} ${input_file_r2} \
        --use-names --memory-mapping
    }

    output {
        File output_tsv_file = output_tsv_name
        File report_txt_file = report_txt_name
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_6c85305847034eadb18c77824949bcc6_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

# Task to merge Kraken2 TSV outputs

task MergeTSVTask {
    input {
        Array[File] input_files
    }

    command {
        cat ${sep=" " input_files} | awk '!seen[$0]++' > merged_taxonomy.tsv
    }

    output {
        File merged_tsv = "merged_taxonomy.tsv"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_a185cfae5f194b339ad0cc511cc46eeb_private:latest"
        cpu: 1
        memory: "1 GB"
    }
}

# Task to generate BIOM file from Kraken2 reports

task kraken_biom {
    input {
        Array[File] input_files
        String output_filename
    }

    command {
        kraken-biom ${sep=" " input_files} --fmt hdf5 -o ${output_filename}
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_5adecffec5fc45f0980a2a9b7ba0b607_private:latest"
        cpu: 16
        memory: "32 GB"
    }

    output {
        File output_biom = "${output_filename}"
    }
}

# Task to generate Krona visualizations

task krona {
    input {
        File input_file
        String output_filename
    }

    command {
        ktImportTaxonomy \
        -o ${output_filename} \
        ${input_file}
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_209cb871c67c4cb3996ac80e426f45c6_private:latest"
        cpu: 16
        memory: "32 GB"
    }

    output {
        File output_html = "${output_filename}"
    }
}

# Task to convert Kraken2 TSV to QIIME2 compatible format

task ConvertKraken2Tsv {
    input {
        File qiime2_merged_taxonomy_tsv
        File taxonomy_convert_script
    }

    command {
        python3 ${taxonomy_convert_script} ${qiime2_merged_taxonomy_tsv} merge_converted_taxonomy.tsv
    }

    output {
        File merge_converted_taxonomy = "merge_converted_taxonomy.tsv"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_41343869128b4502a4801b3f5078e89e_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

# QIIME2 tasks for further analysis

task ImportFeatureTable {
    input {
        File input_biom
    }

    command {
        qiime tools import \
        --type 'FeatureTable[Frequency]' \
        --input-path ${input_biom} \
        --output-path feature-table.qza
    }

    output {
        File output_qza = "feature-table.qza"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

task ImportTaxonomy {
    input {
        File input_tsv
    }

    command {
        qiime tools import \
        --type 'FeatureData[Taxonomy]' \
        --input-format HeaderlessTSVTaxonomyFormat \
        --input-path ${input_tsv} \
        --output-path taxonomy.qza
    }

    output {
        File output_qza = "taxonomy.qza"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

task FilterLowAbundanceFeatures {
    input {
        File input_table
        Int qiime2_min_frequency
    }

    command {
        qiime feature-table filter-features \
        --i-table ${input_table} \
        --p-min-frequency ${qiime2_min_frequency} \
        --o-filtered-table filtered-table.qza
    }

    output {
        File filtered_table = "filtered-table.qza"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

task FilterRareFeatures {
    input {
        File input_table
        Int qiime2_min_samples
    }

    command {
        qiime feature-table filter-features \
        --i-table ${input_table} \
        --p-min-samples ${qiime2_min_samples} \
        --o-filtered-table filtered-table.qza
    }

    output {
        File filtered_table = "filtered-table.qza"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

task RarefyTable {
    input {
        File input_table
        Int qiime2_sampling_depth
    }

    command {
        # qiime feature-table rarefy \
        # --i-table ${input_table} \
        # --p-sampling-depth ${qiime2_sampling_depth} \
        # --o-rarefied-table rarefied-table.qza
    }

    output {
        File rarefied_table = input_table
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

task CalculateAlphaDiversity {
    input {
        File input_table
    }

    command {
        qiime diversity alpha \
        --i-table ${input_table} \
        --p-metric shannon \
        --o-alpha-diversity alpha-diversity.qza
    }

    output {
        File alpha_diversity = "alpha-diversity.qza"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

task ExportAlphaDiversity {
    input {
        File input_qza
    }

    command {
        qiime tools export \
        --input-path ${input_qza} \
        --output-path exported-diversity
    }

    output {
        File exported_diversity = "exported-diversity/alpha-diversity.tsv"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
    }
}

task CalculateBetaDiversity {
    input {
        File input_table
    }

    command {
        qiime diversity beta \
        --i-table ${input_table} \
        --p-metric braycurtis \
        --o-distance-matrix distance-matrix.qza
    }

    output {
        File distance_matrix = "distance-matrix.qza"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

task PerformPCoA {
    input {
        File distance_matrix
    }

    command {
        qiime diversity pcoa \
        --i-distance-matrix ${distance_matrix} \
        --o-pcoa pcoa.qza
    }

    output {
        File pcoa = "pcoa.qza"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}

task AddPseudocount {
    input {
        File input_table
    }

    command {
        qiime composition add-pseudocount \
        --i-table ${input_table} \
        --o-composition-table comp-table.qza
    }

    output {
        File comp_table = "comp-table.qza"
    }

    runtime {
        docker_url: "stereonote_ali_hpc_external/jiashuai.shi_b7ebfb99c10844d99bdc7d0a36398879_private:latest"
        cpu: 16
        memory: "32 GB"
    }
}