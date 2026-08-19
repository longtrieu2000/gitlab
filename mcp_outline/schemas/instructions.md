Manages documents in Outline, a wiki and knowledge base. Use for searching, reading, navigating, editing, and organizing documents and collections.

Finding content: search_documents or get_document_id_from_title to get document IDs, list_collections to discover collections, list_recently_updated_documents to see what changed recently.

Large documents: start with get_document_toc to see heading structure, then read_document_section to read by heading, search_document_content to grep for text, or read_document with offset/limit for line ranges.

Editing: use edit_document for targeted changes. Batch all changes into one call when possible. Use update_document only for full content replacement, title changes, or appending.

Large rewrites: call edit_document with save=False to stage changes across multiple calls, then pass save=True on the final call.

Markdown: Outline uses standard markdown. For Mermaid diagrams use mermaidjs (not mermaid) as the code fence language.