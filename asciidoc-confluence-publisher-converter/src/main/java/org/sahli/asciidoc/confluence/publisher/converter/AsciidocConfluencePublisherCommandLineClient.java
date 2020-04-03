/*
 * Copyright 2018 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.sahli.asciidoc.confluence.publisher.converter;

import static java.nio.file.FileVisitResult.CONTINUE;
import static java.nio.file.Files.createDirectory;
import static java.nio.file.Files.delete;
import static java.nio.file.Files.walkFileTree;

import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.Collections;
import java.util.Map;

public class AsciidocConfluencePublisherCommandLineClient {

	public static void main(String[] args) throws Exception {
		ArgumentsParser argumentsParser = new ArgumentsParser();

		Path documentationRootFolder = Paths.get(argumentsParser.mandatoryArgument("asciidocRootFolder", args));
		Charset sourceEncoding = Charset.forName(argumentsParser.optionalArgument("sourceEncoding", args).orElse("UTF-8"));
		Map<String, Object> attributes = argumentsParser.optionalJsonArgument("attributes", args).orElseGet(Collections::emptyMap);

		Path convertDirPath = Paths.get("/tmp/confluence-converts");
		if (!Files.exists(convertDirPath)) {
			createDirectory(convertDirPath);
		}
		Path newDirectoryForConvert = Paths.get("/tmp/confluence-converts/" + documentationRootFolder.getFileName());
		Path buildFolder = createDirectory(newDirectoryForConvert);
		try {
			AsciidocPagesStructureProvider asciidocPagesStructureProvider = new FolderBasedAsciidocPagesStructureProvider(documentationRootFolder, sourceEncoding);

			AsciidocConfluenceConverter asciidocConfluenceConverter = new AsciidocConfluenceConverter();
			asciidocConfluenceConverter.convert(asciidocPagesStructureProvider, buildFolder, attributes);
		} catch (Exception e) {
			deleteDirectory(buildFolder);
			throw e;
		}
	}

	private static void deleteDirectory(Path buildFolder) throws IOException {
		walkFileTree(buildFolder, new SimpleFileVisitor<Path>() {

			@Override
			public FileVisitResult visitFile(Path path, BasicFileAttributes attributes) throws IOException {
				delete(path);

				return CONTINUE;
			}

			@Override
			public FileVisitResult postVisitDirectory(Path path, IOException e) throws IOException {
				delete(path);

				return CONTINUE;
			}

		});
	}
}
