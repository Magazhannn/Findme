import React, { useState, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { FiUploadCloud, FiCheck } from "react-icons/fi";

/**
 * HeroUploadSection
 * "Quiet Harbor" design — organic, calming, anti-anxiety UI
 * Drag & drop photo upload with water-ripple animation
 */
export const HeroUploadSection = ({ onFileSelected }) => {
  const [isDragging, setIsDragging] = useState(false);
  const [file, setFile] = useState(null);
  const inputRef = useRef(null);

  const handleFile = (selectedFile) => {
    setFile(selectedFile);
    if (onFileSelected) onFileSelected(selectedFile);
    // TODO: trigger Edge AI face extraction here
  };

  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => setIsDragging(false);

  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files?.[0]) {
      handleFile(e.dataTransfer.files[0]);
    }
  };

  const handleClick = () => inputRef.current?.click();

  const handleInputChange = (e) => {
    if (e.target.files?.[0]) {
      handleFile(e.target.files[0]);
    }
  };

  return (
    <section className="min-h-[60vh] flex flex-col items-center justify-center bg-background px-4 py-16">
      {/* Headline */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        className="text-center mb-12"
      >
        <h1 className="text-4xl md:text-5xl font-medium text-text-main tracking-tight mb-4 leading-tight">
          find missing people instantly.
        </h1>
        <p className="text-text-muted text-lg max-w-xl mx-auto leading-relaxed">
          upload a photo or describe the person. our ai will search across
          cameras and networks safely and quietly.
        </p>
      </motion.div>

      {/* Drop Zone */}
      <motion.div
        className={`relative w-full max-w-2xl h-72 rounded-3xl flex flex-col items-center
          justify-center border-2 border-dashed cursor-pointer
          transition-colors duration-500 bg-surface shadow-soft
          ${isDragging ? "border-primary bg-primary-light" : "border-gray-200 hover:border-primary"}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={handleClick}
        whileHover={{ scale: 1.01 }}
        transition={{ type: "spring", stiffness: 300, damping: 20 }}
        role="button"
        tabIndex={0}
        aria-label="Upload photo"
      >
        {/* Water ripple pulse animation while dragging */}
        <AnimatePresence>
          {isDragging && (
            <motion.div
              key="ripple"
              initial={{ scale: 0.6, opacity: 0 }}
              animate={{ scale: 1.6, opacity: 0.12 }}
              exit={{ scale: 0.6, opacity: 0 }}
              transition={{ repeat: Infinity, duration: 1.6, ease: "easeInOut" }}
              className="absolute w-56 h-56 bg-primary rounded-full blur-3xl pointer-events-none"
            />
          )}
        </AnimatePresence>

        <div className="z-10 flex flex-col items-center select-none">
          {file ? (
            <>
              <FiCheck className="text-5xl text-primary mb-4" />
              <p className="text-text-main font-medium text-lg">{file.name}</p>
              <p className="text-text-muted text-sm mt-1">
                click to replace
              </p>
            </>
          ) : (
            <>
              <FiUploadCloud
                className={`text-5xl mb-4 transition-colors duration-500 ${
                  isDragging ? "text-primary" : "text-gray-300"
                }`}
              />
              <p className="text-text-main font-medium text-lg">
                drag &amp; drop photo here
              </p>
              <p className="text-text-muted text-sm mt-2">or click to browse</p>
            </>
          )}
        </div>

        {/* Hidden file input */}
        <input
          ref={inputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handleInputChange}
        />
      </motion.div>
    </section>
  );
};

export default HeroUploadSection;
